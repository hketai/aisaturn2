class Api::V1::Accounts::InboxesController < Api::V1::Accounts::BaseController
  include Api::V1::InboxesHelper
  before_action :fetch_inbox, except: [:index, :create]
  before_action :fetch_agent_bot, only: [:set_agent_bot]
  before_action :validate_limit, only: [:create]
  # we are already handling the authorization in fetch inbox
  before_action :check_authorization, except: [:show, :health]
  before_action :validate_whatsapp_cloud_channel, only: [:health]

  def index
    @inboxes = policy_scope(Current.account.inboxes.order_by_name.includes(:channel, { avatar_attachment: [:blob] }))
  end

  def show; end

  # Deprecated: This API will be removed in 2.7.0
  def assignable_agents
    @assignable_agents = @inbox.assignable_agents
  end

  def campaigns
    @campaigns = @inbox.campaigns
  end

  def avatar
    @inbox.avatar.attachment.destroy! if @inbox.avatar.attached?
    head :ok
  end

  def create
    Rails.logger.error "=== Inbox Creation Debug ==="
    Rails.logger.error "params: #{params.inspect}"
    
    # Get channel type first to determine editable attributes
    channel_type = params.dig(:inbox, :channel, :type)
    Rails.logger.error "channel_type from params: #{channel_type.inspect}"
    
    # Get channel class to determine editable attributes
    channel_class = channel_type.present? ? channel_type_from_params_for_type(channel_type) : nil
    Rails.logger.error "channel_class: #{channel_class.inspect}"
    
    # Get editable attributes
    channel_attributes = channel_class.present? && channel_class.const_defined?(:EDITABLE_ATTRS) ? channel_class::EDITABLE_ATTRS : []
    Rails.logger.error "channel_attributes: #{channel_attributes.inspect}"
    
    # Now get permitted params with channel attributes
    permitted = permitted_params(channel_attributes)
    Rails.logger.error "permitted_params: #{permitted.inspect}"
    Rails.logger.error "permitted_params[:channel]: #{permitted[:channel].inspect}"
    
    # For WhatsApp Web, create channel outside transaction to ensure it's committed
    channel = create_channel_with_permitted(permitted)
    Rails.logger.error "create_channel returned: #{channel.inspect}"
    if channel.nil?
      Rails.logger.error "Channel creation failed - channel is nil!"
      raise StandardError, 'Channel creation failed'
    end

    # For WhatsApp Web, don't create inbox until connection is established
    if channel.is_a?(Channel::WhatsappWeb)
      # Store inbox name in channel's provider_config for later use
      inbox_name_value = permitted[:name] || inbox_name(channel)
      channel.update!(provider_config: (channel.provider_config || {}).merge(pending_inbox_name: inbox_name_value))
      
      # Ensure channel is persisted and reloaded
      channel.reload
      
      # Return channel only, inbox will be created after QR scan
      render json: {
        channel: channel.as_json(only: [:id, :account_id, :phone_number, :status, :provider_config, :qr_code_token, :qr_code_expires_at, :created_at, :updated_at]),
        inbox: nil,
        requires_qr_scan: true,
        message: 'Channel created. Please scan QR code to complete setup.'
      }
      return
    end

    # For other channels, create inbox in transaction
    ActiveRecord::Base.transaction do
      @inbox = Current.account.inboxes.build(
        {
          name: inbox_name(channel),
          channel: channel
        }.merge(
          permitted.except(:channel)
        )
      )
      @inbox.save!
      Rails.logger.debug "=== End Inbox Creation Debug ==="
    end
  rescue StandardError => e
    Rails.logger.error "Inbox creation error: #{e.class.name}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n") if Rails.env.development?
    render json: { error: e.message, message: e.message }, status: :unprocessable_entity
  end

  def update
    inbox_params = permitted_params.except(:channel, :csat_config)
    inbox_params[:csat_config] = format_csat_config(permitted_params[:csat_config]) if permitted_params[:csat_config].present?
    @inbox.update!(inbox_params)
    update_inbox_working_hours
    update_channel if channel_update_required?
  end

  def agent_bot
    @agent_bot = @inbox.agent_bot
  end

  def set_agent_bot
    if @agent_bot
      agent_bot_inbox = @inbox.agent_bot_inbox || AgentBotInbox.new(inbox: @inbox)
      agent_bot_inbox.agent_bot = @agent_bot
      agent_bot_inbox.save!
    elsif @inbox.agent_bot_inbox.present?
      @inbox.agent_bot_inbox.destroy!
    end
    head :ok
  end

  def destroy
    if @inbox.present?
      # In development, perform synchronously if Sidekiq is not running
      # In production, always use background job
      if Rails.env.development? && !sidekiq_running?
        ::DeleteObjectJob.perform_now(@inbox, Current.user, request.ip)
        render status: :ok, json: { message: I18n.t('messages.inbox_deletetion_response') }
      else
        ::DeleteObjectJob.perform_later(@inbox, Current.user, request.ip)
        render status: :ok, json: { message: I18n.t('messages.inbox_deletetion_response') }
      end
    else
      render status: :not_found, json: { error: 'Inbox not found' }
    end
  rescue StandardError => e
    Rails.logger.error "Inbox deletion error: #{e.class.name}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n") if Rails.env.development?
    render status: :unprocessable_entity, json: { error: e.message, message: "Silme işlemi başarısız: #{e.message}" }
  end

  def sync_templates
    return render status: :unprocessable_entity, json: { error: 'Template sync is only available for WhatsApp channels' } unless whatsapp_channel?

    trigger_template_sync
    render status: :ok, json: { message: 'Template sync initiated successfully' }
  rescue StandardError => e
    render status: :internal_server_error, json: { error: e.message }
  end

  def health
    health_data = Whatsapp::HealthService.new(@inbox.channel).fetch_health_status
    render json: health_data
  rescue StandardError => e
    Rails.logger.error "[INBOX HEALTH] Error fetching health data: #{e.message}"
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params[:id])
    authorize @inbox, :show?
  end

  def fetch_agent_bot
    @agent_bot = AgentBot.find(params[:agent_bot]) if params[:agent_bot]
  end

  def validate_whatsapp_cloud_channel
    return if @inbox.channel.is_a?(Channel::Whatsapp) && @inbox.channel.provider == 'whatsapp_cloud'

    render json: { error: 'Health data only available for WhatsApp Cloud API channels' }, status: :bad_request
  end

  def create_channel_with_permitted(permitted)
    Rails.logger.error "=== Channel Creation Debug ==="
    Rails.logger.error "permitted[:channel]: #{permitted[:channel].inspect}"
    
    unless permitted[:channel].present?
      Rails.logger.error "permitted[:channel] is not present!"
      return nil
    end
    
    channel_type = permitted[:channel][:type]
    Rails.logger.error "channel_type: #{channel_type.inspect}"
    Rails.logger.error "allowed_channel_types: #{allowed_channel_types.inspect}"
    Rails.logger.error "is allowed? #{allowed_channel_types.include?(channel_type)}"
    
    unless allowed_channel_types.include?(channel_type)
      Rails.logger.error "channel_type '#{channel_type}' is not in allowed_channel_types!"
      return nil
    end

    channel_class = channel_type_from_params_for_type(channel_type)
    Rails.logger.error "channel_class: #{channel_class.inspect}"
    if channel_class.nil?
      Rails.logger.error "channel_class is nil!"
      return nil
    end

    channel_method = account_channels_method_for_type(channel_type)
    Rails.logger.error "channel_method: #{channel_method.inspect}"
    if channel_method.nil?
      Rails.logger.error "channel_method is nil!"
      return nil
    end

    channel_attrs = permitted[:channel].except(:type)
    Rails.logger.error "channel_attrs: #{channel_attrs.inspect}"
    
    result = channel_method.create!(channel_attrs)
    Rails.logger.error "channel created: #{result.inspect}"
    Rails.logger.error "=== End Channel Creation Debug ==="
    result
  rescue StandardError => e
    Rails.logger.error "Channel creation error: #{e.class.name}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n") if Rails.env.development?
    raise
  end

  def channel_type_from_params_for_type(channel_type)
    {
      'web_widget' => Channel::WebWidget,
      'api' => Channel::Api,
      'email' => Channel::Email,
      'line' => Channel::Line,
      'telegram' => Channel::Telegram,
      'whatsapp' => Channel::Whatsapp,
      'whatsapp_web' => Channel::WhatsappWeb,
      'sms' => Channel::Sms
    }[channel_type]
  end

  def account_channels_method_for_type(channel_type)
    {
      'web_widget' => Current.account.web_widgets,
      'api' => Current.account.api_channels,
      'email' => Current.account.email_channels,
      'line' => Current.account.line_channels,
      'telegram' => Current.account.telegram_channels,
      'whatsapp' => Current.account.whatsapp_channels,
      'whatsapp_web' => Current.account.channel_whatsapp_webs,
      'sms' => Current.account.sms_channels
    }[channel_type]
  end

  def allowed_channel_types
    %w[web_widget api email line telegram whatsapp whatsapp_web sms]
  end

  def update_inbox_working_hours
    @inbox.update_working_hours(params.permit(working_hours: Inbox::OFFISABLE_ATTRS)[:working_hours]) if params[:working_hours]
  end

  def update_channel
    channel_attributes = get_channel_attributes(@inbox.channel_type)
    return if permitted_params(channel_attributes)[:channel].blank?

    validate_and_update_email_channel(channel_attributes) if @inbox.inbox_type == 'Email'

    reauthorize_and_update_channel(channel_attributes)
    update_channel_feature_flags
  end

  def channel_update_required?
    permitted_params(get_channel_attributes(@inbox.channel_type))[:channel].present?
  end

  def validate_and_update_email_channel(channel_attributes)
    validate_email_channel(channel_attributes)
  rescue StandardError => e
    render json: { message: e }, status: :unprocessable_entity and return
  end

  def reauthorize_and_update_channel(channel_attributes)
    @inbox.channel.reauthorized! if @inbox.channel.respond_to?(:reauthorized!)
    @inbox.channel.update!(permitted_params(channel_attributes)[:channel])
  end

  def update_channel_feature_flags
    return unless @inbox.web_widget?
    return unless permitted_params(Channel::WebWidget::EDITABLE_ATTRS)[:channel].key? :selected_feature_flags

    @inbox.channel.selected_feature_flags = permitted_params(Channel::WebWidget::EDITABLE_ATTRS)[:channel][:selected_feature_flags]
    @inbox.channel.save!
  end

  def format_csat_config(config)
    {
      display_type: config['display_type'] || 'emoji',
      message: config['message'] || '',
      survey_rules: {
        operator: config.dig('survey_rules', 'operator') || 'contains',
        values: config.dig('survey_rules', 'values') || []
      }
    }
  end

  def inbox_attributes
    [:name, :avatar, :greeting_enabled, :greeting_message, :enable_email_collect, :csat_survey_enabled,
     :enable_auto_assignment, :working_hours_enabled, :out_of_office_message, :timezone, :allow_messages_after_resolved,
     :lock_to_single_conversation, :portal_id, :sender_name_type, :business_name,
     { csat_config: [:display_type, :message, { survey_rules: [:operator, { values: [] }] }] }]
  end

  def permitted_params(channel_attributes = [])
    # We will remove this line after fixing https://linear.app/chatwoot/issue/CW-1567/null-value-passed-as-null-string-to-backend
    params.each { |k, v| params[k] = params[k] == 'null' ? nil : v }

    Rails.logger.error "permitted_params called with channel_attributes: #{channel_attributes.inspect}"
    Rails.logger.error "params[:inbox]: #{params[:inbox].inspect}"
    Rails.logger.error "params.inspect: #{params.inspect}"
    
    # Flatten channel_attributes array to handle nested hashes
    channel_permit_array = [:type]
    channel_attributes.each do |attr|
      if attr.is_a?(Hash)
        attr.each do |key, value|
          if value.is_a?(Hash)
            channel_permit_array << { key => value }
          else
            channel_permit_array << { key => [] }
          end
        end
      else
        channel_permit_array << attr
      end
    end
    
    Rails.logger.error "channel_permit_array: #{channel_permit_array.inspect}"
    
    # Use require(:inbox) to ensure inbox params are present
    inbox_params = params.require(:inbox)
    Rails.logger.error "inbox_params after require: #{inbox_params.inspect}"
    
    result = inbox_params.permit(
      *inbox_attributes,
      channel: channel_permit_array
    )
    
    Rails.logger.error "permitted_params result: #{result.inspect}"
    result
  end

  def channel_type_from_params
    {
      'web_widget' => Channel::WebWidget,
      'api' => Channel::Api,
      'email' => Channel::Email,
      'line' => Channel::Line,
      'telegram' => Channel::Telegram,
      'whatsapp' => Channel::Whatsapp,
      'whatsapp_web' => Channel::WhatsappWeb,
      'sms' => Channel::Sms
    }[permitted_params[:channel][:type]]
  end

  def get_channel_attributes(channel_type)
    if channel_type.constantize.const_defined?(:EDITABLE_ATTRS)
      channel_type.constantize::EDITABLE_ATTRS.presence
    else
      []
    end
  end

  def whatsapp_channel?
    @inbox.whatsapp? || (@inbox.twilio? && @inbox.channel.whatsapp?)
  end

  def trigger_template_sync
    if @inbox.whatsapp?
      Channels::Whatsapp::TemplatesSyncJob.perform_later(@inbox.channel)
    elsif @inbox.twilio? && @inbox.channel.whatsapp?
      Channels::Twilio::TemplatesSyncJob.perform_later(@inbox.channel)
    end
  end

  def sidekiq_running?
    # Check if Sidekiq is running by checking if there are any processes
    # In development, if Sidekiq is not running, perform synchronously
    require 'sidekiq/api'
    Sidekiq::ProcessSet.new.size > 0
  rescue StandardError
    # If we can't check (e.g., Redis not available), assume Sidekiq is not running
    false
  end
end

Api::V1::Accounts::InboxesController.prepend_mod_with('Api::V1::Accounts::InboxesController')

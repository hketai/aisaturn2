class Ikas::CallbacksController < ApplicationController
  include Ikas::IntegrationHelper

  def show
    verify_state!
    exchange_code_for_token!
    create_or_update_hook!
    start_initial_sync!

    redirect_to ikas_integration_url
  rescue StandardError => e
    Rails.logger.error("[Ikas] Callback error: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    redirect_to "#{redirect_url}?error=true&message=#{CGI.escape(e.message)}"
  end

  private

  def verify_state!
    state = params[:state]
    raise StandardError, 'State parametresi eksik' if state.blank?

    # Get state data from Redis
    state_json = Redis::Alfred.get("ikas_oauth_state:#{state}")
    raise StandardError, 'Geçersiz veya süresi dolmuş state' if state_json.blank?

    @state_data = JSON.parse(state_json)
    @account_id = @state_data['account_id']
    @store_name = @state_data['store_name']

    raise StandardError, 'Account ID bulunamadı' if @account_id.blank?

    # Delete state from Redis (one-time use)
    Redis::Alfred.delete("ikas_oauth_state:#{state}")
  end

  def exchange_code_for_token!
    code = params[:code]
    raise StandardError, 'Authorization code eksik' if code.blank?

    @token_response = exchange_ikas_code_for_token(code)
    raise StandardError, 'Token alınamadı' if @token_response.blank? || @token_response['access_token'].blank?
  end

  def create_or_update_hook!
    # Test connection and get merchant info
    merchant_info = test_ikas_connection(@token_response['access_token'])

    # Create or update the hook
    hook = Integrations::Hook.find_or_initialize_by(
      account_id: @account_id,
      app_id: 'ikas'
    )

    hook.reference_id = @store_name
    hook.access_token = @token_response['access_token']
    hook.status = :enabled
    hook.settings ||= {}
    hook.settings['refresh_token'] = @token_response['refresh_token']
    hook.settings['token_expires_at'] = Time.current + @token_response['expires_in'].to_i.seconds if @token_response['expires_in']
    hook.settings['scope'] = @token_response['scope']

    if merchant_info
      hook.settings['merchant_email'] = merchant_info['email']
      storefront = merchant_info['storefront']
      if storefront
        hook.settings['storefront_name'] = storefront['name']
        hook.settings['storefront_domain'] = storefront.dig('domain', 'domain')
      end
    end

    hook.save!

    @hook = hook
    Rails.logger.info "[Ikas] Integration connected for account #{@account_id}, store: #{@store_name}"
  end

  def start_initial_sync!
    # Start product sync job
    Ikas::SyncProductsMasterJob.perform_later(@account_id, @hook.id, incremental: false)
    Rails.logger.info "[Ikas] Initial sync started for account #{@account_id}"
  rescue StandardError => e
    Rails.logger.warn "[Ikas] Failed to start initial sync: #{e.message}"
    # Don't raise - the hook is already created
  end

  def account
    @account ||= Account.find(@account_id)
  end

  def ikas_integration_url
    "#{ENV.fetch('FRONTEND_URL', nil)}/app/accounts/#{@account_id}/settings/saturn/integrations?ikas=connected"
  end

  def redirect_url
    if @account_id
      "#{ENV.fetch('FRONTEND_URL', nil)}/app/accounts/#{@account_id}/settings/saturn/integrations"
    else
      ENV.fetch('FRONTEND_URL', nil)
    end
  end
end


class Api::V1::Accounts::Saturn::AssistantsController < Api::V1::Accounts::BaseController
  before_action :authenticate_and_authorize
  before_action :load_assistant, except: [:index, :create]

  def index
    load_assistants_list
  end

  def show; end

  def create
    build_new_assistant
    save_assistant
    render :show, status: :created
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Saturn assistant creation failed: #{e.message}")
    render json: { error: e.record.errors.full_messages.join(', ') }, status: :unprocessable_entity
  rescue StandardError => e
    Rails.logger.error("Saturn assistant creation error: #{e.class.name}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n")) if Rails.env.development?
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update
    update_assistant_attributes
    save_assistant
    render :show
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Saturn assistant update failed: #{e.message}")
    render json: { error: e.record.errors.full_messages.join(', ') }, status: :unprocessable_entity
  rescue StandardError => e
    Rails.logger.error("Saturn assistant update error: #{e.class.name}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n")) if Rails.env.development?
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update_working_hours
    update_working_hours_config
    save_assistant
    render :show
  end

  def update_handoff_settings
    update_handoff_config
    save_assistant
    render :show
  end

  def destroy
    remove_assistant
  end

  def playground
    generate_playground_response
  end

  private

  def authenticate_and_authorize
    authorize :saturn_assistant, :show?
  end

  def load_assistants_list
    @assistants = Current.account.saturn_assistants
                         .includes(:documents, :responses, :inboxes)
                         .for_account(Current.account.id)
    apply_search_filter if params[:searchKey].present?
    apply_pagination
  end

  def apply_search_filter
    search_term = "%#{params[:searchKey]}%"
    @assistants = @assistants.where('name ILIKE ?', search_term)
  end

  def apply_pagination
    @assistants = @assistants.page(params[:page] || 1)
  end

  def load_assistant
    @assistant = Current.account.saturn_assistants.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error("Saturn assistant not found: #{params[:id]}")
    render json: { error: 'Assistant not found' }, status: :not_found
  end

  def build_new_assistant
    @assistant = Current.account.saturn_assistants.build(permitted_assistant_params)
  end

  def update_assistant_attributes
    @assistant.assign_attributes(permitted_assistant_params)
  end

  def save_assistant
    @assistant.save!
  end

  def remove_assistant
    @assistant.destroy!
    head :ok
  end

  def generate_playground_response
    user_input = params[:message_content]
    history = params[:message_history] || []

    Rails.logger.debug do
      "Saturn playground params: message_content=#{user_input.present?}, message_history=#{history.class}, assistant_id=#{@assistant&.id}"
    end

    return render json: { error: 'message_content is required' }, status: :bad_request if user_input.blank?

    # Normalize message history format
    normalized_history = normalize_message_history(history)

    chat_service = Saturn::Llm::AssistantChatService.new(assistant: @assistant)

    ai_response = chat_service.create_ai_response(
      user_message: user_input,
      conversation_history: normalized_history
    )

    render json: { message: ai_response }
  rescue StandardError => e
    Rails.logger.error("Saturn playground error: #{e.class.name}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n")) if Rails.env.development?
    error_message = e.message.include?('API key') ? 'OpenAI API key not configured' : e.message
    render json: { error: error_message }, status: :unprocessable_entity
  end

  def normalize_message_history(history)
    return [] unless history.is_a?(Array)

    history.map do |msg|
      if msg.is_a?(Hash)
        {
          role: msg[:role] || msg['role'] || 'user',
          content: msg[:content] || msg['content'] || ''
        }
      else
        { role: 'user', content: msg.to_s }
      end
    end
  end

  def update_working_hours_config
    working_hours_params = params.permit(working_hours: [:day_of_week, :open_hour, :open_minutes, :close_hour, :close_minutes, :closed_all_day,
                                                         :open_all_day])
    return unless working_hours_params[:working_hours].present?

    @assistant.config ||= {}
    @assistant.config['working_hours'] = working_hours_params[:working_hours]
  end

  def update_handoff_config
    handoff_params = params.permit(handoff_config: [:enabled,
                                                    { intents: [:id, :name, :enabled, :keywords, { handoff_target: [:type, :assistant_id] },
                                                                :handoff_message] }])
    return unless handoff_params[:handoff_config].present?

    @assistant.config ||= {}
    @assistant.config['handoff_config'] = handoff_params[:handoff_config]
  end

  def permitted_assistant_params
    params.require(:assistant).permit(:name, :description, config: {}, response_guidelines: [], guardrails: [])
  end
end

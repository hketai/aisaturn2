require 'openai'

class Saturn::Llm::BaseOpenAiService
  DEFAULT_MODEL = 'gpt-4o-mini'.freeze

  def initialize
    setup_api_credentials
    initialize_openai_client
    configure_model
  rescue StandardError => e
    raise "Saturn OpenAI initialization failed: #{e.message}"
  end

  protected

  def execute_chat_api(messages:, tools: nil, temperature: nil)
    api_params = build_chat_params(messages, tools, temperature)
    api_response = call_openai_api(api_params)
    extract_message_content(api_response)
  rescue StandardError => e
    handle_api_error(e)
    raise
  end

  private

  def setup_api_credentials
    # Priority: Account-specific key > Global Super Admin key
    account = Current.account
    account_key = account&.openai_api_key&.presence
    
    if account_key.present?
      @api_key = account_key
    else
      # Fallback to Super Admin Saturn settings (SATURN_OPEN_AI_API_KEY)
      @api_key = InstallationConfig.find_by(name: 'SATURN_OPEN_AI_API_KEY')&.value
    end
    
    raise 'Saturn OpenAI API key not configured' if @api_key.blank?

    endpoint_config = InstallationConfig.find_by(name: 'SATURN_OPEN_AI_ENDPOINT')&.value
    @endpoint = endpoint_config.presence || 'https://api.openai.com/'
    @endpoint = @endpoint.chomp('/')
  end

  def initialize_openai_client
    @client = OpenAI::Client.new(
      access_token: @api_key,
      uri_base: @endpoint,
      log_errors: Rails.env.development?
    )
  end

  def configure_model
    model_config = InstallationConfig.find_by(name: 'SATURN_OPEN_AI_MODEL')&.value
    @model = model_config.presence || DEFAULT_MODEL
  end

  def build_chat_params(messages, tools, temperature)
    params = {
      model: @model,
      messages: messages
    }
    params[:tools] = tools if tools.present?
    params[:temperature] = temperature if temperature.present?
    
    # Debug: Log messages being sent to OpenAI
    Rails.logger.error("=== OpenAI API Request ===")
    Rails.logger.error("Model: #{@model}")
    Rails.logger.error("Messages count: #{messages.length}")
    Rails.logger.error("First message role: #{messages.first[:role]}")
    Rails.logger.error("First message content preview: #{messages.first[:content]&.first(200)}...")
    Rails.logger.error("All message roles: #{messages.map { |m| m[:role] }.inspect}")
    Rails.logger.error("=== End API Request ===")
    
    params
  end

  def call_openai_api(params)
    @client.chat(parameters: params)
  end

  def extract_message_content(api_response)
    api_response.dig('choices', 0, 'message', 'content')
  end

  def handle_api_error(error)
    Rails.logger.error("Saturn OpenAI API Error: #{error.message}")
    Rails.logger.error(error.backtrace.join("\n")) if Rails.env.development?
  end
end

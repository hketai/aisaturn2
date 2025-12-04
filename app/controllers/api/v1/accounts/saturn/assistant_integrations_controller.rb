class Api::V1::Accounts::Saturn::AssistantIntegrationsController < Api::V1::Accounts::BaseController
  before_action :set_assistant
  before_action :set_integration, only: [:update, :destroy]

  def index
    integrations = @assistant.assistant_integrations
    
    # Mevcut entegrasyonları döndür
    render json: {
      integrations: integrations.map do |i|
        {
          id: i.id,
          integration_type: i.integration_type,
          enabled: i.enabled
        }
      end,
      enabled_integrations: @assistant.enabled_integrations
    }
  end

  def create
    integration = @assistant.assistant_integrations.find_or_initialize_by(
      integration_type: params[:integration_type]
    )
    integration.enabled = params[:enabled] != false
    
    if integration.save
      render json: {
        id: integration.id,
        integration_type: integration.integration_type,
        enabled: integration.enabled
      }, status: :created
    else
      render json: { errors: integration.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @integration.update(enabled: params[:enabled])
      render json: {
        id: @integration.id,
        integration_type: @integration.integration_type,
        enabled: @integration.enabled
      }
    else
      render json: { errors: @integration.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def toggle
    integration_type = params[:integration_type]
    new_status = @assistant.toggle_integration!(integration_type)
    
    render json: {
      integration_type: integration_type,
      enabled: new_status
    }
  end

  def destroy
    @integration.destroy!
    head :no_content
  end

  private

  def set_assistant
    @assistant = Current.account.saturn_assistants.find(params[:assistant_id])
  end

  def set_integration
    @integration = @assistant.assistant_integrations.find(params[:id])
  end
end


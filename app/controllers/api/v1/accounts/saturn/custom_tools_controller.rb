class Api::V1::Accounts::Saturn::CustomToolsController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_tool, except: [:index, :create]

  def index
    @tools = Current.account.saturn_custom_tools.ordered
    @tools = @tools.enabled if params[:enabled] == 'true'
    @tools = @tools.page(params[:page])
  end

  def show; end

  def create
    @tool = Current.account.saturn_custom_tools.build(tool_params)
    @tool.save!
  end

  def update
    @tool.update!(tool_params)
  end

  def destroy
    @tool.destroy!
    head :ok
  end

  private

  def fetch_tool
    @tool = Current.account.saturn_custom_tools.find(params[:id])
  end

  def tool_params
    params.require(:custom_tool).permit(
      :slug, :title, :description, :http_method, :endpoint_url,
      :request_template, :response_template, :auth_type, :enabled,
      auth_config: {}, param_schema: []
    )
  end

  def check_authorization
    authorize :saturn_custom_tool, :show?
  end
end


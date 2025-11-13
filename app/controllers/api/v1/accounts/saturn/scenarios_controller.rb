class Api::V1::Accounts::Saturn::ScenariosController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_scenario, except: [:index, :create]
  before_action :fetch_assistant, only: [:index, :create]

  def index
    @scenarios = @assistant.scenarios.ordered
    @scenarios = @scenarios.page(params[:page])
  end

  def show; end

  def create
    @scenario = @assistant.scenarios.build(scenario_params)
    @scenario.account = Current.account
    @scenario.save!
  end

  def update
    @scenario.update!(scenario_params)
  end

  def destroy
    @scenario.destroy!
    head :ok
  end

  private

  def fetch_assistant
    @assistant = Current.account.saturn_assistants.find(params[:assistant_id])
  end

  def fetch_scenario
    @scenario = Current.account.saturn_scenarios.find(params[:id])
  end

  def scenario_params
    params.require(:scenario).permit(:title, :description, :instruction, :enabled, tools: [])
  end

  def check_authorization
    authorize :saturn_scenario, :show?
  end
end


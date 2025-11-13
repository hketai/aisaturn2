class Api::V1::Accounts::Saturn::ResponsesController < Api::V1::Accounts::BaseController
  before_action :authenticate_and_authorize
  before_action :load_assistant_for_listing, only: [:create]
  before_action :load_response, except: [:index, :create, :search]

  def index
    load_responses_list
  end

  def show; end

  def create
    build_new_response
    assign_account_to_response
    save_response
  end

  def update
    update_response_attributes
    save_response
  end

  def destroy
    remove_response
  end

  def search
    perform_response_search
  end

  private

  def authenticate_and_authorize
    authorize :saturn_response, :show?
  end

  def load_assistant_for_listing
    return unless params[:assistant_id].present?

    @assistant = Current.account.saturn_assistants.find(params[:assistant_id])
  end

  def load_responses_list
    @responses = Current.account.saturn_assistant_responses.includes(:assistant, :documentable).ordered

    if params[:assistant_id].present?
      @assistant = Current.account.saturn_assistants.find(params[:assistant_id])
      @responses = @responses.by_assistant(@assistant.id)
    end

    apply_response_filters
    apply_response_pagination
  end

  def apply_response_filters
    @responses = @responses.where(status: params[:status]) if params[:status].present? && params[:status] != 'all'

    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @responses = @responses.where(
        'question ILIKE :search OR answer ILIKE :search',
        search: search_term
      )
    end
  end

  def apply_response_pagination
    @responses = @responses.page(params[:page] || 1)
  end

  def load_response
    @response = Current.account.saturn_assistant_responses.find(params[:id])
  end

  def build_new_response
    @assistant = Current.account.saturn_assistants.find(params[:assistant_id])
    @response = @assistant.responses.build(permitted_response_params)
  end

  def assign_account_to_response
    @response.account = Current.account
  end

  def update_response_attributes
    @response.assign_attributes(permitted_response_params)
  end

  def save_response
    @response.save!
  end

  def remove_response
    @response.destroy!
    head :ok
  end

  def perform_response_search
    query = params[:query]
    @responses = Saturn::AssistantResponse.find_by_query(query)
      .by_account(Current.account.id)
      .limit(10)
    render :index
  end

  def permitted_response_params
    params.require(:response).permit(:question, :answer, :status, :documentable_type, :documentable_id)
  end
end

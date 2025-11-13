class Api::V1::Accounts::Saturn::InboxesController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_assistant

  def index
    @inboxes = @assistant.inboxes
  end

  def create
    inbox_id = params.dig(:inbox, :inbox_id) || params[:inbox_id]
    inbox = Current.account.inboxes.find(inbox_id)
    @saturn_inbox = @assistant.saturn_inboxes.find_or_create_by!(inbox: inbox)
    render :index
  end

  def destroy
    inbox_id = params[:inbox_id]
    inbox = Current.account.inboxes.find(inbox_id)
    @saturn_inbox = @assistant.saturn_inboxes.find_by!(inbox: inbox)
    @saturn_inbox.destroy!
    head :ok
  end

  private

  def fetch_assistant
    @assistant = Current.account.saturn_assistants.find(params[:assistant_id])
  end

  def check_authorization
    authorize :saturn_inbox, :show?
  end
end


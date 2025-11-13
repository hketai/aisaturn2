class Api::V1::Accounts::Saturn::DocumentsController < Api::V1::Accounts::BaseController
  before_action :authenticate_and_authorize
  before_action :load_assistant_for_listing, only: [:create]
  before_action :load_document, except: [:index, :create]

  def index
    load_documents_list
  end

  def show; end

  def create
    build_new_document
    assign_account_to_document
    save_document
  end

  def update
    update_document_attributes
    save_document
  end

  def destroy
    remove_document
  end

  private

  def authenticate_and_authorize
    authorize :saturn_document, :show?
  end

  def load_assistant_for_listing
    return unless params[:assistant_id].present?

    @assistant = Current.account.saturn_assistants.find(params[:assistant_id])
  end

  def load_documents_list
    @documents = Current.account.saturn_documents.includes(:assistant).ordered

    if params[:assistant_id].present?
      @assistant = Current.account.saturn_assistants.find(params[:assistant_id])
      @documents = @documents.for_assistant(@assistant.id)
    end

    apply_document_pagination
  end

  def apply_document_pagination
    @documents = @documents.page(params[:page] || 1)
  end

  def load_document
    @document = Current.account.saturn_documents.find(params[:id])
  end

  def build_new_document
    @assistant = Current.account.saturn_assistants.find(params[:assistant_id])
    @document = @assistant.documents.build(permitted_document_params)
  end

  def assign_account_to_document
    @document.account = Current.account
  end

  def update_document_attributes
    @document.assign_attributes(permitted_document_params)
  end

  def save_document
    @document.save!
  end

  def remove_document
    @document.destroy!
    head :ok
  end

  def permitted_document_params
    params.require(:document).permit(:name, :external_link, :content, :pdf_file, metadata: {})
  end
end

# == Schema Information
#
# Table name: saturn_documents
#
#  id            :bigint           not null, primary key
#  content       :text
#  external_link :string           not null
#  metadata      :jsonb
#  name          :string           not null
#  status        :integer          default("in_progress"), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :bigint           not null
#  assistant_id  :bigint           not null
#
# Indexes
#
#  index_saturn_documents_on_account_id                      (account_id)
#  index_saturn_documents_on_assistant_id                    (assistant_id)
#  index_saturn_documents_on_assistant_id_and_external_link  (assistant_id,external_link) UNIQUE
#  index_saturn_documents_on_status                          (status)
#
class Saturn::Document < ApplicationRecord
  class DocumentLimitError < StandardError; end

  self.table_name = 'saturn_documents'

  # Associations - different order
  belongs_to :account
  belongs_to :assistant, class_name: 'Saturn::Assistant'
  has_many :responses, class_name: 'Saturn::AssistantResponse', dependent: :destroy, as: :documentable
  has_one_attached :pdf_file

  # Status enum
  enum status: {
    in_progress: 0,
    available: 1
  }

  # Validations - different approach
  validates :name, presence: true
  validates :account_id, presence: true
  validates :assistant_id, presence: true
  validates :content, length: { maximum: 200_000 }, allow_blank: true
  validates :external_link, presence: true, unless: :has_pdf_attachment?
  validates :external_link, uniqueness: { scope: :assistant_id }, allow_blank: true
  validate :must_have_pdf_if_pdf_type, if: :is_pdf_document?
  validate :pdf_format_check, if: :has_pdf_attachment?
  validate :file_size_check, if: :has_pdf_attachment?

  # Callbacks - different order
  before_validation :sync_account_from_assistant
  before_validation :generate_pdf_link_if_needed
  after_create_commit :enqueue_processing_job

  # Scopes
  scope :for_account, ->(account_id) { where(account_id: account_id) }
  scope :for_assistant, ->(assistant_id) { where(assistant_id: assistant_id) }
  scope :ordered, -> { order(created_at: :desc) }
  scope :available_docs, -> { where(status: :available) }

  # Public methods - different organization
  def is_pdf_document?
    return true if has_pdf_attachment? && pdf_file.blob.content_type == 'application/pdf'
    external_link&.ends_with?('.pdf')
  end

  def has_pdf_attachment?
    pdf_file.attached?
  end

  def mime_type
    pdf_file.blob.content_type if has_pdf_attachment?
  end

  def attachment_size
    pdf_file.blob.byte_size if has_pdf_attachment?
  end

  def ai_file_identifier
    metadata&.dig('openai_file_id')
  end

  def save_ai_file_identifier(file_id)
    current_metadata = metadata || {}
    update!(metadata: current_metadata.merge('openai_file_id' => file_id))
  end

  def url_for_display
    return external_link if external_link.present? && !external_link.start_with?('PDF:')
    has_pdf_attachment? ? "PDF: #{name}" : external_link
  end

  private

  def sync_account_from_assistant
    self.account_id = assistant&.account_id if account_id.blank?
  end

  def generate_pdf_link_if_needed
    return unless has_pdf_attachment?
    self.external_link = "PDF: #{pdf_file.filename}" if external_link.blank?
  end

  def must_have_pdf_if_pdf_type
    errors.add(:pdf_file, 'must be attached for PDF documents') unless has_pdf_attachment?
  end

  def pdf_format_check
    return unless has_pdf_attachment?
    errors.add(:pdf_file, 'must be a PDF file') unless pdf_file.content_type == 'application/pdf'
  end

  def file_size_check
    return unless has_pdf_attachment?
    errors.add(:pdf_file, 'file size exceeds 10MB limit') if pdf_file.byte_size > 10.megabytes
  end

  def enqueue_processing_job
    Saturn::DocumentProcessingJob.perform_later(id)
  end
end

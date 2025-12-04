# == Schema Information
#
# Table name: saturn_document_chunks
#
#  id           :bigint           not null, primary key
#  content      :text             not null
#  chunk_index  :integer          default(0)
#  embedding    :vector(1536)
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  document_id  :bigint           not null
#  account_id   :bigint           not null
#
# Indexes
#
#  index_saturn_document_chunks_on_account_id   (account_id)
#  index_saturn_document_chunks_on_chunk_index  (chunk_index)
#  index_saturn_document_chunks_on_document_id  (document_id)
#  idx_saturn_doc_chunks_embedding              (embedding) USING ivfflat
#
class Saturn::DocumentChunk < ApplicationRecord
  self.table_name = 'saturn_document_chunks'

  # Associations
  belongs_to :document, class_name: 'Saturn::Document'
  belongs_to :account

  # Vector search
  has_neighbors :embedding, normalize: true

  # Validations
  validates :content, presence: true
  validates :document_id, presence: true
  validates :account_id, presence: true

  # Scopes
  scope :ordered, -> { order(:chunk_index) }
  scope :with_embedding, -> { where.not(embedding: nil) }
  scope :for_account, ->(account_id) { where(account_id: account_id) }

  # Callbacks
  before_validation :sync_account_from_document
  after_commit :enqueue_embedding_update, on: [:create, :update], if: :saved_change_to_content?

  private

  def sync_account_from_document
    self.account_id = document&.account_id if account_id.blank?
  end

  def enqueue_embedding_update
    Saturn::UpdateDocumentChunkEmbeddingJob.perform_later(id)
  end
end


class Saturn::UpdateDocumentChunkEmbeddingJob < ApplicationJob
  queue_as :low

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(chunk_id)
    chunk = Saturn::DocumentChunk.find_by(id: chunk_id)
    return unless chunk

    Rails.logger.info "[SATURN DOC EMBEDDING] Updating embedding for chunk ##{chunk_id}"

    embedding_service = Saturn::Llm::EmbeddingService.new
    embedding_vector = embedding_service.create_vector_embedding(chunk.content)

    chunk.update_column(:embedding, embedding_vector)

    Rails.logger.info "[SATURN DOC EMBEDDING] Successfully updated embedding for chunk ##{chunk_id}"
  rescue Saturn::Llm::EmbeddingService::EmbeddingsError => e
    Rails.logger.error "[SATURN DOC EMBEDDING] Failed: #{e.message}"
    raise
  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn "[SATURN DOC EMBEDDING] Chunk ##{chunk_id} not found, skipping"
  end
end


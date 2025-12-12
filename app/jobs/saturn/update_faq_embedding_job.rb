class Saturn::UpdateFaqEmbeddingJob < ApplicationJob
  queue_as :low

  # Retry on transient errors
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(response_id)
    response = Saturn::AssistantResponse.find_by(id: response_id)
    return unless response

    Rails.logger.info "[SATURN EMBEDDING] Updating embedding for FAQ ##{response_id}"

    # Combine question and answer for better semantic representation
    text_content = build_embedding_text(response)
    
    # Generate embedding via OpenAI
    embedding_service = Saturn::Llm::EmbeddingService.new
    embedding_vector = embedding_service.create_vector_embedding(text_content)

    # Update the record directly (skip callbacks to avoid infinite loop)
    response.update_column(:embedding, embedding_vector)

    Rails.logger.info "[SATURN EMBEDDING] Successfully updated embedding for FAQ ##{response_id}"
  rescue Saturn::Llm::EmbeddingService::EmbeddingsError => e
    Rails.logger.error "[SATURN EMBEDDING] Failed to create embedding for FAQ ##{response_id}: #{e.message}"
    raise # Re-raise to trigger retry
  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn "[SATURN EMBEDDING] FAQ ##{response_id} not found, skipping"
  end

  private

  def build_embedding_text(response)
    # Include both question and answer for richer semantic context
    "Soru: #{response.question}\nCevap: #{response.answer}"
  end
end


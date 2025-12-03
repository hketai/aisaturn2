require 'openai'

class Saturn::Llm::EmbeddingService < Saturn::Llm::BaseOpenAiService
  class EmbeddingsError < StandardError; end

  def self.embedding_model
    @embedding_model ||= fetch_embedding_model_config
  end

  def create_vector_embedding(text_content, model: self.class.embedding_model)
    embedding_params = build_embedding_params(text_content, model)
    api_response = call_embedding_api(embedding_params)
    extract_embedding_from_response(api_response)
  rescue StandardError => e
    handle_embedding_error(e)
    raise EmbeddingsError, "Saturn embedding creation failed: #{e.message}"
  end

  private

  def self.fetch_embedding_model_config
    config_value = InstallationConfig.find_by(name: 'SATURN_EMBEDDING_MODEL')&.value
    config_value.presence || OpenAiConstants::DEFAULT_EMBEDDING_MODEL
  end

  def build_embedding_params(text_content, model)
    {
      model: model,
      input: text_content
    }
  end

  def call_embedding_api(params)
    @client.embeddings(parameters: params)
  end

  def extract_embedding_from_response(api_response)
    api_response.dig('data', 0, 'embedding')
  end

  def handle_embedding_error(error)
    Rails.logger.error("Saturn embedding error: #{error.message}")
    Rails.logger.error(error.backtrace.join("\n")) if Rails.env.development?
  end
end

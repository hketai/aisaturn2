class Saturn::DocumentProcessingJob < ApplicationJob
  queue_as :medium

  retry_on StandardError, wait: 5.seconds, attempts: 3

  def perform(document_id)
    document = Saturn::Document.find(document_id)
    service = Saturn::DocumentProcessingService.new(document)
    service.process
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("Saturn document not found: #{e.message}")
  rescue StandardError => e
    Rails.logger.error("Saturn document processing job failed: #{e.message}")
    raise
  end
end


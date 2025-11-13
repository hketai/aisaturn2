class Saturn::DocumentProcessingService
  class ProcessingError < StandardError; end

  def initialize(document)
    @document = document
  end

  def process
    return unless document_needs_processing?

    if document.has_pdf_attachment?
      process_pdf_document
    elsif document.external_link.present?
      process_external_link_document
    end

    mark_document_as_available
  rescue StandardError => e
    handle_processing_error(e)
    raise ProcessingError, "Saturn document processing failed: #{e.message}"
  end

  private

  attr_reader :document

  def document_needs_processing?
    document.in_progress? && document.content.blank?
  end

  def process_pdf_document
    pdf_service = Saturn::Llm::PdfProcessingService.new(document)
    file_id = pdf_service.process
    
    # Extract content from PDF using OpenAI (if file_id is available)
    if file_id.present?
      # For now, we store a reference to the OpenAI file
      # The actual content extraction can be done via OpenAI Assistants API if needed
      # For prompt usage, we'll note that content is available via OpenAI file
      document.update!(
        content: "PDF içeriği OpenAI'de işlendi. File ID: #{file_id}"
      )
    end
  end

  def process_external_link_document
    extracted_content = extract_content_from_url(document.external_link)
    document.update!(content: extracted_content) if extracted_content.present?
  end

  def extract_content_from_url(url)
    return nil if url.blank? || url.start_with?('PDF:')

    begin
      require 'open-uri'
      require 'nokogiri'
      
      # Fetch the URL content
      html_content = URI.open(url, 'User-Agent' => 'Mozilla/5.0', read_timeout: 10).read
      doc = Nokogiri::HTML(html_content)
      
      # Remove script and style elements
      doc.css('script, style, noscript').remove
      
      # Extract main content
      # Try to find main content area, otherwise use body
      main_content = doc.at_css('main, article, [role="main"]') || doc.at_css('body')
      
      # Extract text content and clean it up
      text_content = main_content&.text&.strip
      
      # Limit content size (200k characters max)
      if text_content && text_content.length > 200_000
        text_content = text_content.first(200_000) + "\n\n[Content truncated...]"
      end
      
      text_content || "URL içeriği alınamadı: #{url}"
    rescue StandardError => e
      Rails.logger.error("Saturn URL extraction error: #{e.message}")
      "URL içeriği alınamadı: #{url} (Hata: #{e.message})"
    end
  end

  def mark_document_as_available
    document.update!(status: :available)
  end

  def handle_processing_error(error)
    Rails.logger.error("Saturn document processing error: #{error.message}")
    Rails.logger.error(error.backtrace.join("\n")) if Rails.env.development?
    document.update!(status: :in_progress) # Keep as in_progress on error
  end
end


require 'openai'

class Saturn::Llm::PdfProcessingService < Saturn::Llm::BaseOpenAiService
  class PdfProcessingError < StandardError; end

  def initialize(document)
    super()
    @document = document
  end

  def process
    return if document.ai_file_identifier.present?

    file_id = upload_pdf_to_openai
    raise PdfProcessingError, 'Saturn PDF upload failed' if file_id.blank?

    document.save_ai_file_identifier(file_id)
    file_id
  end

  private

  attr_reader :document

  def upload_pdf_to_openai
    with_tempfile do |temp_file|
      response = @client.files.upload(
        parameters: {
          file: temp_file,
          purpose: 'assistants'
        }
      )
      response['id']
    end
  end

  def with_tempfile(&)
    Tempfile.create(['saturn_pdf_upload', '.pdf'], binmode: true) do |temp_file|
      temp_file.write(document.pdf_file.download)
      temp_file.close

      File.open(temp_file.path, 'rb', &)
    end
  end
end


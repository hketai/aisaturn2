class Saturn::DocumentProcessingService
  class ProcessingError < StandardError; end

  # Akıllı Chunking Konfigürasyonu
  MIN_CHUNK_SIZE = 200    # Minimum chunk boyutu
  TARGET_CHUNK_SIZE = 400 # Hedef chunk boyutu
  MAX_CHUNK_SIZE = 600    # Maximum chunk boyutu
  OVERLAP_SENTENCES = 1   # Örtüşme için kaç cümle

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

    # İçerik işlendikten sonra chunk'ları oluştur
    create_document_chunks if document.content.present?

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

  def create_document_chunks
    return if document.content.blank?

    # Önce mevcut chunk'ları sil (yeniden işleme durumunda)
    document.chunks.destroy_all

    # Akıllı chunking uygula
    chunks = smart_chunk(document.content)

    Rails.logger.info "[SMART CHUNKING] Creating #{chunks.size} chunks for document ##{document.id}"

    chunks.each_with_index do |chunk_content, index|
      document.chunks.create!(
        content: chunk_content,
        chunk_index: index,
        account_id: document.account_id
      )
    end

    Rails.logger.info "[SMART CHUNKING] Successfully created #{chunks.size} chunks for document ##{document.id}"
  end

  # ===== AKILLI CHUNKING ALGORİTMASI =====

  def smart_chunk(content)
    return [] if content.blank?

    # 1. İçeriği temizle
    cleaned = clean_content(content)

    # 2. Önce paragraflara böl
    paragraphs = split_into_paragraphs(cleaned)

    # 3. Paragrafları cümlelere böl ve chunk'la
    chunks = []
    current_chunk = []
    current_length = 0

    paragraphs.each do |paragraph|
      sentences = split_into_sentences(paragraph)

      sentences.each do |sentence|
        sentence = sentence.strip
        next if sentence.empty?

        sentence_length = sentence.length

        # Cümle tek başına MAX'dan büyükse, akıllıca böl
        if sentence_length > MAX_CHUNK_SIZE
          # Önce mevcut chunk'ı kaydet
          if current_chunk.any?
            chunks << finalize_chunk(current_chunk)
            current_chunk = get_overlap_sentences(current_chunk)
            current_length = current_chunk.join(' ').length
          end

          # Büyük cümleyi parçalara böl
          sub_chunks = split_long_sentence(sentence)
          sub_chunks.each { |sc| chunks << sc }
          next
        end

        # Mevcut chunk'a ekleyince MAX'ı aşacak mı?
        if current_length + sentence_length + 1 > MAX_CHUNK_SIZE
          # Mevcut chunk yeterli büyüklükte mi?
          if current_length >= MIN_CHUNK_SIZE
            chunks << finalize_chunk(current_chunk)
            # Örtüşme için son cümleleri al
            current_chunk = get_overlap_sentences(current_chunk)
            current_length = current_chunk.join(' ').length
          end
        end

        # Cümleyi ekle
        current_chunk << sentence
        current_length += sentence_length + 1
      end

      # Paragraf sonu - eğer chunk yeterli büyüklükteyse kaydet
      if current_length >= TARGET_CHUNK_SIZE
        chunks << finalize_chunk(current_chunk)
        current_chunk = get_overlap_sentences(current_chunk)
        current_length = current_chunk.join(' ').length
      end
    end

    # Son chunk'ı ekle
    if current_chunk.any?
      final = finalize_chunk(current_chunk)
      # Çok kısa ise öncekiyle birleştir
      if final.length < MIN_CHUNK_SIZE && chunks.any?
        chunks[-1] = chunks[-1] + ' ' + final
      else
        chunks << final
      end
    end

    # Son kontrol: çok kısa chunk'ları birleştir
    merge_tiny_chunks(chunks)
  end

  def clean_content(content)
    content
      .gsub(/\r\n/, "\n")           # Windows satır sonlarını düzelt
      .gsub(/\t/, ' ')              # Tab'ları boşluğa çevir
      .gsub(/ +/, ' ')              # Çoklu boşlukları teke indir
      .gsub(/\n{4,}/, "\n\n\n")     # 4+ satır boşluğu 3'e indir
      .strip
  end

  def split_into_paragraphs(content)
    # Çift satır sonu veya heading'lerden böl
    # Not: \# kullanıyoruz çünkü # Ruby'de interpolasyon karakteri
    content.split(/\n{2,}|(?=^\#{1,6}\s)/m).map(&:strip).reject(&:empty?)
  end

  def split_into_sentences(text)
    # Türkçe ve İngilizce cümle sonu işaretleri
    # Kısaltmaları korumaya çalış (Dr., Mr., vb.)
    text
      .gsub(/([.!?।؟])(\s+)(?=[A-ZÇĞİÖŞÜА-Я])/, "\\1\n")
      .gsub(/([.!?।؟])(\s*)$/, "\\1\n")
      .split("\n")
      .map(&:strip)
      .reject(&:empty?)
  end

  def split_long_sentence(sentence)
    # Uzun cümleyi virgül, noktalı virgül veya "ve/veya" dan böl
    parts = sentence.split(/[,;]\s*|\s+ve\s+|\s+veya\s+|\s+and\s+|\s+or\s+/i)

    chunks = []
    current = ''

    parts.each do |part|
      part = part.strip
      next if part.empty?

      if (current + ' ' + part).length > MAX_CHUNK_SIZE
        chunks << current.strip unless current.empty?
        current = part
      else
        current += (current.empty? ? '' : ' ') + part
      end
    end

    chunks << current.strip unless current.empty?

    # Hala çok uzunsa kelime bazında böl
    chunks.flat_map { |chunk| chunk.length > MAX_CHUNK_SIZE ? split_by_words(chunk) : chunk }
  end

  def split_by_words(text)
    words = text.split(' ')
    chunks = []
    current = ''

    words.each do |word|
      if (current + ' ' + word).length > MAX_CHUNK_SIZE
        chunks << current.strip unless current.empty?
        current = word
      else
        current += (current.empty? ? '' : ' ') + word
      end
    end

    chunks << current.strip unless current.empty?
    chunks
  end

  def get_overlap_sentences(sentences)
    # Son N cümleyi örtüşme olarak al
    sentences.last(OVERLAP_SENTENCES)
  end

  def finalize_chunk(sentences)
    sentences.join(' ').strip
  end

  def merge_tiny_chunks(chunks)
    return chunks if chunks.size <= 1

    merged = []
    buffer = ''

    chunks.each do |chunk|
      if buffer.empty?
        buffer = chunk
      elsif buffer.length < MIN_CHUNK_SIZE
        # Buffer çok küçük, birleştir
        buffer = buffer + ' ' + chunk
      elsif (buffer + ' ' + chunk).length <= MAX_CHUNK_SIZE
        # Birleştirme MAX'ı aşmıyorsa birleştir
        buffer = buffer + ' ' + chunk
      else
        # Buffer'ı kaydet, yeni chunk'a geç
        merged << buffer
        buffer = chunk
      end
    end

    merged << buffer unless buffer.empty?
    merged
  end
end



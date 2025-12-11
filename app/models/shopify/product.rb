# == Schema Information
#
# Table name: shopify_products
#
#  id                 :bigint           not null, primary key
#  description        :text
#  embedding          :vector(1536)
#  external_id        :string
#  handle             :string
#  images             :jsonb
#  last_queried_at    :datetime
#  last_synced_at     :datetime
#  max_price          :decimal(10, 2)
#  min_price          :decimal(10, 2)
#  product_type       :string
#  source             :string           default("shopify"), not null
#  title              :string
#  total_inventory    :integer          default(0)
#  variants           :jsonb
#  vendor             :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  account_id         :bigint           not null
#  hook_id            :bigint
#  shopify_product_id :bigint
#
# Indexes
#
#  index_shopify_products_on_account_and_shopify_product_id  (account_id,shopify_product_id) UNIQUE
#  index_shopify_products_on_account_id                      (account_id)
#  index_shopify_products_on_embedding                       (embedding) USING ivfflat
#  index_shopify_products_on_hook_id                         (hook_id)
#  index_shopify_products_on_last_queried_at                 (last_queried_at)
#  index_shopify_products_on_last_synced_at                  (last_synced_at)
#  index_shopify_products_on_source                          (source)
#  idx_products_account_source_external                      (account_id,source,external_id) UNIQUE
#
module Shopify
  class Product < Shopify::ApplicationRecord
    self.table_name = 'shopify_products'

    # Manuel attribute tanımları (schema cache sorunu için)
    attribute :source, :string, default: 'shopify'
    attribute :external_id, :string
    attribute :content_hash, :string
    attribute :image_hash, :string

    # Kaynak türleri
    SOURCES = {
      shopify: 'shopify',
      manual: 'manual',
      woocommerce: 'woocommerce',
      trendyol: 'trendyol'
    }.freeze

    # Neighbor gem için vector search desteği
    has_neighbors :embedding, normalize: true

    belongs_to :account, class_name: '::Account', foreign_key: 'account_id'
    belongs_to :hook, class_name: '::Integrations::Hook', foreign_key: 'hook_id', optional: true

    # Validasyonlar
    validates :account_id, presence: true
    validates :title, presence: true
    validates :source, presence: true, inclusion: { in: SOURCES.values }
    validates :external_id, uniqueness: { scope: [:account_id, :source] }, allow_nil: true
    # shopify_product_id sadece shopify source için zorunlu (legacy uyumluluk)
    validates :shopify_product_id, uniqueness: { scope: :account_id }, allow_nil: true

    # Scopes
    scope :for_account, ->(account_id) { where(account_id: account_id) }
    scope :by_source, ->(source) { where(source: source) }
    scope :from_shopify, -> { by_source(SOURCES[:shopify]) }
    scope :manual, -> { by_source(SOURCES[:manual]) }
    scope :in_stock, -> { where('total_inventory > 0') }
    scope :recently_queried, -> { where('last_queried_at > ?', 30.days.ago) }
    scope :needs_sync, -> { where('last_synced_at < ? OR last_synced_at IS NULL', 24.hours.ago) }
    scope :with_embedding, -> { where.not(embedding: nil) }

    # Associations
    has_many :product_embeddings, class_name: 'Shopify::ProductEmbedding', foreign_key: 'shopify_product_id', dependent: :destroy
    has_many :product_image_embeddings, class_name: 'Shopify::ProductImageEmbedding', foreign_key: 'shopify_product_id', dependent: :destroy

    # Callbacks - embedding artık gece job'ı ile yapılıyor
    # after_save :update_embedding_async, if: :should_update_embedding?

    # Helper metodlar
    def shopify?
      source == SOURCES[:shopify]
    end

    def manual?
      source == SOURCES[:manual]
    end

    def in_stock?
      total_inventory.to_i.positive?
    end
    
    # Vector search (pgvector extension gerekli) - Legacy method
    def self.semantic_search(query_embedding, account_id:, limit: 10)
      return none unless query_embedding.present?
      
      where(account_id: account_id)
        .where.not(embedding: nil)
        .order(Arel.sql("embedding <-> '#{query_embedding}'::vector"))
        .limit(limit)
    rescue StandardError => e
      Rails.logger.error("Semantic search failed: #{e.message}")
      none
    end
    
    # Text search
    def self.text_search(query, account_id:, limit: 10)
      where(account_id: account_id)
        .where("title ILIKE ? OR description ILIKE ?", "%#{query}%", "%#{query}%")
        .limit(limit)
    end
    
    def update_embedding!
      unless description.present? || title.present?
        Rails.logger.warn("[EMBEDDING] Product #{id} has no title or description, skipping")
        return false
      end

      # Title, description, varyant ve görsel açıklamasını birleştir
      text_parts = [title, description, variant_titles_text, image_description].compact.reject(&:blank?)
      text_content = text_parts.join(' ')

      # Text çok kısaysa skip
      if text_content.length < 3
        Rails.logger.warn("[EMBEDDING] Product #{id} text too short, skipping")
        return false
      end

      embedding_service = Saturn::Llm::EmbeddingService.new
      embedding_vector = embedding_service.create_vector_embedding(text_content)

      if embedding_vector.blank?
        Rails.logger.error("[EMBEDDING] Product #{id}: Empty embedding returned")
        raise "Empty embedding returned for product #{id}"
      end

      update_column(:embedding, embedding_vector)
      true
    rescue StandardError => e
      Rails.logger.error("[EMBEDDING] Failed to update embedding for product #{id}: #{e.class} - #{e.message}")
      # Hatayı yukarı fırlat ki job retry yapabilsin
      raise
    end

    # Jina CLIP ile gerçek image embedding oluştur
    def create_image_embedding!
      return false if images.blank?

      img_url = images.is_a?(Array) ? images.first&.dig('src') : nil
      return false if img_url.blank?

      clip_service = Saturn::JinaClipService.new
      embedding = clip_service.embed_image(img_url)

      return false if embedding.blank?

      # Vector tipine uygun format (pgvector için)
      embedding_string = "[#{embedding.join(',')}]"
      self.class.connection.execute(
        "UPDATE shopify_products SET image_embedding = '#{embedding_string}', image_embedded_at = NOW() WHERE id = #{id}"
      )

      Rails.logger.info "[JINA CLIP] Product #{id} image embedded (#{embedding.size} dims)"
      true
    rescue StandardError => e
      Rails.logger.error "[JINA CLIP] Product #{id} failed: #{e.message}"
      false
    end

    # İlk resim URL'sini al
    def first_image_url
      return nil if images.blank?

      images.is_a?(Array) ? images.first&.dig('src') : nil
    end

    # DEPRECATED: GPT-4o ile analiz (text-based yaklaşım)
    def analyze_image!
      return false if images.blank?

      first_image_url = images.is_a?(Array) ? images.first&.dig('src') : nil
      return false if first_image_url.blank?

      analysis_service = Saturn::ImageAnalysisService.new(account: account)
      description_text = analysis_service.analyze_product_image(first_image_url)

      return false if description_text.blank?

      update_columns(image_description: description_text, image_analyzed_at: Time.current)
      Rails.logger.info "[IMAGE ANALYSIS] Product #{id}: #{description_text}"
      true
    rescue StandardError => e
      Rails.logger.error "[IMAGE ANALYSIS] Product #{id} failed: #{e.message}"
      false
    end

    # Varyant title'larını text olarak döndür (renk, beden vb. bilgileri içerir)
    def variant_titles_text
      return nil if variants.blank?

      variant_list = variants.is_a?(String) ? JSON.parse(variants) : variants
      titles = variant_list.map { |v| v['title'] }.compact.uniq
      titles.join(' ')
    rescue StandardError
      nil
    end
    
    def mark_queried!
      update_column(:last_queried_at, Time.current)
    end

    # Content hash hesaplama - ERP güncellemelerinden etkilenmemek için
    def calculate_content_hash
      content = [title, description, product_type, vendor]
      if variants.present?
        variant_list = variants.is_a?(String) ? JSON.parse(variants) : variants
        variant_data = variant_list.map { |v| "#{v['title']}:#{v['price']}:#{v['sku']}" }
        content += variant_data
      end
      Digest::MD5.hexdigest(content.compact.join('|'))
    rescue StandardError
      Digest::MD5.hexdigest([title, description].compact.join('|'))
    end

    # Image hash hesaplama - görsel değişikliklerini takip etmek için
    def calculate_image_hash
      return nil if images.blank?

      image_list = images.is_a?(String) ? JSON.parse(images) : images
      image_urls = image_list.map { |img| img['src'] }.compact
      return nil if image_urls.empty?

      Digest::MD5.hexdigest(image_urls.sort.join('|'))
    rescue StandardError
      nil
    end

    # Content değişti mi kontrolü
    def content_changed?
      calculate_content_hash != content_hash
    end

    # Image değişti mi kontrolü
    def image_changed?
      calculate_image_hash != image_hash
    end

    # Mevcut embedding'i al (yeni tablo üzerinden)
    def current_embedding
      product_embeddings.find_by(content_hash: content_hash)&.embedding
    end

    # Mevcut image embedding'i al (yeni tablo üzerinden)
    def current_image_embedding
      product_image_embeddings.find_by(image_hash: image_hash)&.embedding
    end

    private

    def should_update_embedding?
      saved_change_to_title? || saved_change_to_description? || saved_change_to_product_type? || saved_change_to_variants? || saved_change_to_image_description?
    end

    def update_embedding_async
      # DEPRECATED: Artık gece job'ı ile yapılıyor
      # ::Shopify::UpdateProductEmbeddingJob.perform_later(id)
    end
  end
end


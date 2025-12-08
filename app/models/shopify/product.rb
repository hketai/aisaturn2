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

    # Callbacks
    after_save :update_embedding_async, if: :should_update_embedding?

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
      
      text_content = [title, description].compact.join(' ')
      
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
    
    def mark_queried!
      update_column(:last_queried_at, Time.current)
    end

    private

    def should_update_embedding?
      saved_change_to_title? || saved_change_to_description? || saved_change_to_product_type?
    end

    def update_embedding_async
      ::Shopify::UpdateProductEmbeddingJob.perform_later(id)
    end
  end
end


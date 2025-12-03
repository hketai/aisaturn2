# == Schema Information
#
# Table name: shopify_products
#
#  id                 :bigint           not null, primary key
#  description        :text
#  embedding          :vector(1536)
#  handle             :string
#  images             :jsonb
#  last_queried_at    :datetime
#  last_synced_at     :datetime
#  max_price          :decimal(10, 2)
#  min_price          :decimal(10, 2)
#  product_type       :string
#  title              :string
#  total_inventory    :integer          default(0)
#  variants           :jsonb
#  vendor             :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  account_id         :bigint           not null
#  hook_id            :bigint
#  shopify_product_id :bigint           not null
#
# Indexes
#
#  index_shopify_products_on_account_and_shopify_product_id  (account_id,shopify_product_id) UNIQUE
#  index_shopify_products_on_account_id                      (account_id)
#  index_shopify_products_on_embedding                       (embedding) USING ivfflat
#  index_shopify_products_on_hook_id                         (hook_id)
#  index_shopify_products_on_last_queried_at                 (last_queried_at)
#  index_shopify_products_on_last_synced_at                  (last_synced_at)
#
module Shopify
  class Product < Shopify::ApplicationRecord
    self.table_name = 'shopify_products'
    
    # Neighbor gem için vector search desteği
    has_neighbors :embedding, normalize: true
    
    belongs_to :account, class_name: '::Account', foreign_key: 'account_id'
    belongs_to :hook, class_name: '::Integrations::Hook', foreign_key: 'hook_id', optional: true
    
    validates :shopify_product_id, uniqueness: { scope: :account_id }
    validates :account_id, presence: true
    
    scope :for_account, ->(account_id) { where(account_id: account_id) }
    scope :recently_queried, -> { where('last_queried_at > ?', 30.days.ago) }
    scope :needs_sync, -> { where('last_synced_at < ? OR last_synced_at IS NULL', 24.hours.ago) }
    scope :with_embedding, -> { where.not(embedding: nil) }
    
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
  end
end


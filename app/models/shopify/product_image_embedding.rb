# == Schema Information
#
# Table name: product_image_embeddings
#
#  id                 :bigint           not null, primary key
#  shopify_product_id :bigint           not null
#  account_id         :bigint           not null
#  image_hash         :string           not null
#  embedding          :vector(768)
#  embedded_at        :datetime
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  index_product_image_embeddings_on_account_id                        (account_id)
#  index_product_image_embeddings_on_shopify_product_id_and_image_hash (shopify_product_id,image_hash) UNIQUE
#
module Shopify
  class ProductImageEmbedding < Shopify::ApplicationRecord
    self.table_name = 'product_image_embeddings'

    # Neighbor gem için vector search desteği
    has_neighbors :embedding, normalize: true

    belongs_to :shopify_product, class_name: 'Shopify::Product', foreign_key: 'shopify_product_id'
    belongs_to :account, class_name: '::Account', foreign_key: 'account_id'

    validates :image_hash, presence: true
    validates :shopify_product_id, uniqueness: { scope: :image_hash }

    scope :for_account, ->(account_id) { where(account_id: account_id) }
    scope :with_embedding, -> { where.not(embedding: nil) }
    scope :recent, -> { order(embedded_at: :desc) }

    # Görsel arama - Jina CLIP embeddings kullanarak
    def self.image_search(query_embedding, account_id:, limit: 10)
      return none unless query_embedding.present?

      for_account(account_id)
        .with_embedding
        .nearest_neighbors(:embedding, query_embedding, distance: :cosine)
        .limit(limit)
        .includes(:shopify_product)
    end
  end
end


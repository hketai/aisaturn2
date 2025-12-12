class AddImageEmbeddingToShopifyProducts < ActiveRecord::Migration[7.0]
  def change
    # Jina CLIP image embedding için (768 boyutlu vector)
    add_column :shopify_products, :image_embedding, :vector, limit: 768
    add_column :shopify_products, :image_embedded_at, :datetime
  end
end


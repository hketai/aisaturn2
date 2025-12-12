class ChangeImageEmbeddingDimension < ActiveRecord::Migration[7.0]
  def up
    # Mevcut image embedding'leri sil (Jina'dan yarım kalmış olanlar)
    execute "DELETE FROM shopify_product_image_embeddings"
    
    # Embedding kolonunu 768 boyutuna değiştir (CLIP ViT-L-14)
    remove_column :shopify_product_image_embeddings, :embedding
    add_column :shopify_product_image_embeddings, :embedding, :vector, limit: 768
  end

  def down
    remove_column :shopify_product_image_embeddings, :embedding
    add_column :shopify_product_image_embeddings, :embedding, :vector, limit: 1024
  end
end


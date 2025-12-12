class CreateProductImageEmbeddings < ActiveRecord::Migration[7.0]
  def change
    create_table :product_image_embeddings do |t|
      t.references :shopify_product, foreign_key: { to_table: :shopify_products }, null: false
      t.bigint :account_id, null: false
      t.string :image_hash, null: false
      t.vector :embedding, limit: 768 # Jina CLIP dimension
      t.datetime :embedded_at
      t.timestamps
    end

    add_index :product_image_embeddings, :account_id
    add_index :product_image_embeddings, [:shopify_product_id, :image_hash], unique: true, name: 'idx_product_image_embeddings_product_hash'
  end
end


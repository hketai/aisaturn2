class CreateProductEmbeddings < ActiveRecord::Migration[7.0]
  def change
    create_table :product_embeddings do |t|
      t.references :shopify_product, foreign_key: { to_table: :shopify_products }, null: false
      t.bigint :account_id, null: false
      t.string :content_hash, null: false
      t.vector :embedding, limit: 1536
      t.datetime :embedded_at
      t.timestamps
    end

    add_index :product_embeddings, :account_id
    add_index :product_embeddings, [:shopify_product_id, :content_hash], unique: true
  end
end


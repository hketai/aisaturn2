class CreateShopifyProducts < ActiveRecord::Migration[7.1]
  def up
    # Vector extension'ı kontrol et
    enable_extension 'vector' unless extension_enabled?('vector')
    
    create_table :shopify_products do |t|
      t.bigint :account_id, null: false
      t.bigint :hook_id
      t.bigint :shopify_product_id, null: false
      t.string :title
      t.text :description
      t.string :handle
      t.string :vendor
      t.string :product_type
      t.jsonb :variants, default: []
      t.jsonb :images, default: []
      t.decimal :min_price, precision: 10, scale: 2
      t.decimal :max_price, precision: 10, scale: 2
      t.integer :total_inventory, default: 0
      t.vector :embedding, limit: 1536
      t.datetime :last_synced_at
      t.datetime :last_queried_at
      t.timestamps
    end
    
    add_index :shopify_products, [:account_id, :shopify_product_id], unique: true, name: 'index_shopify_products_on_account_and_shopify_product_id'
    add_index :shopify_products, :account_id
    add_index :shopify_products, :hook_id
    add_index :shopify_products, :last_queried_at
    add_index :shopify_products, :last_synced_at
    
    # Vector index (IVFFlat)
    # Not: IVFFlat index için lists parametresi migration sonrası manuel ayarlanmalı
    # Veya connection.execute ile direkt SQL çalıştırılabilir
    connection.execute <<-SQL
      CREATE INDEX index_shopify_products_on_embedding 
      ON shopify_products 
      USING ivfflat (embedding vector_l2_ops) 
      WITH (lists = 100);
    SQL
  rescue ActiveRecord::StatementInvalid => e
    # Vector extension yoksa index oluşturma
    if e.message.include?('vector')
      Rails.logger.warn("Vector extension not available, skipping vector index")
    else
      raise
    end
  end
  
  def down
    drop_table :shopify_products if table_exists?(:shopify_products)
  end
end


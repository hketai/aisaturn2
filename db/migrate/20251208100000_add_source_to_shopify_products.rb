class AddSourceToShopifyProducts < ActiveRecord::Migration[7.0]
  def change
    # Source sütunu: 'shopify', 'manual', 'woocommerce', 'trendyol' vb.
    add_column :shopify_products, :source, :string, default: 'shopify', null: false

    # shopify_product_id artık nullable (manuel ürünler için null olacak)
    change_column_null :shopify_products, :shopify_product_id, true

    # external_id - generic harici ID (shopify, woocommerce vb. için)
    add_column :shopify_products, :external_id, :string

    # Source ve external_id için index
    add_index :shopify_products, :source
    add_index :shopify_products, [:account_id, :source, :external_id], unique: true, 
              where: 'external_id IS NOT NULL', 
              name: 'idx_products_account_source_external'

    # Mevcut shopify_product_id değerlerini external_id'ye kopyala
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE shopify_products 
          SET external_id = shopify_product_id::text 
          WHERE shopify_product_id IS NOT NULL
        SQL
      end
    end
  end
end


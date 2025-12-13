class AddContentHashToShopifyProducts < ActiveRecord::Migration[7.0]
  def change
    add_column :shopify_products, :content_hash, :string unless column_exists?(:shopify_products, :content_hash)
    add_column :shopify_products, :image_hash, :string unless column_exists?(:shopify_products, :image_hash)
    add_index :shopify_products, :content_hash unless index_exists?(:shopify_products, :content_hash)
  end
end


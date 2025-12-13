class AddContentHashToShopifyProducts < ActiveRecord::Migration[7.0]
  def change
    add_column :shopify_products, :content_hash, :string
    add_column :shopify_products, :image_hash, :string
    add_index :shopify_products, :content_hash
  end
end


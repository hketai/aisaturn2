class AddImageDescriptionToShopifyProducts < ActiveRecord::Migration[7.0]
  def change
    # Ürün resminin GPT-4o tarafından oluşturulan açıklaması
    # Bu açıklama embedding'e dahil edilecek ve görsel arama için kullanılacak
    add_column :shopify_products, :image_description, :text
    add_column :shopify_products, :image_analyzed_at, :datetime
  end
end


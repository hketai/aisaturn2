class CreateShopifySyncStatuses < ActiveRecord::Migration[7.1]
  def change
    create_table :shopify_sync_statuses do |t|
      t.bigint :account_id, null: false
      t.bigint :hook_id, null: false
      t.integer :status, default: 0, null: false
      t.integer :total_products, default: 0
      t.integer :synced_products, default: 0
      t.text :error_message
      t.datetime :started_at
      t.datetime :completed_at
      t.datetime :failed_at
      t.timestamps
    end
    
    add_index :shopify_sync_statuses, [:account_id, :hook_id], name: 'index_shopify_sync_statuses_on_account_and_hook'
    add_index :shopify_sync_statuses, :status
    add_index :shopify_sync_statuses, :created_at
  end
end


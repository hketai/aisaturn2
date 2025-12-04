class AddMetadataToAccountSubscriptions < ActiveRecord::Migration[7.1]
  def change
    return unless table_exists?(:account_subscriptions)
    
    add_column :account_subscriptions, :metadata, :jsonb unless column_exists?(:account_subscriptions, :metadata)
  end
end

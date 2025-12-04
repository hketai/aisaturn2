class CreateAccountSubscriptions < ActiveRecord::Migration[7.1]
  def change
    create_table :account_subscriptions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :subscription_plan, null: false, foreign_key: true
      t.string :iyzico_subscription_id
      t.string :status, null: false, default: 'active'
      t.datetime :started_at, null: false
      t.datetime :expires_at
      t.datetime :canceled_at
      t.jsonb :metadata

      t.timestamps
    end

    add_index :account_subscriptions, :status
    add_index :account_subscriptions, [:account_id, :status]
    add_index :account_subscriptions, :iyzico_subscription_id
  end
end

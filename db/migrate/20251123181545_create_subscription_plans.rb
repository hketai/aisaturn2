class CreateSubscriptionPlans < ActiveRecord::Migration[7.1]
  def change
    create_table :subscription_plans do |t|
      t.string :name, null: false
      t.text :description
      t.decimal :price, precision: 10, scale: 2, default: 0.0
      t.integer :message_limit, default: 0
      t.integer :conversation_limit, default: 0
      t.integer :agent_limit
      t.integer :inbox_limit
      t.string :billing_cycle
      t.integer :trial_days
      t.jsonb :features
      t.boolean :is_active, default: true, null: false
      t.boolean :is_free, default: false, null: false
      t.integer :position, default: 0

      t.timestamps
    end

    add_index :subscription_plans, :is_active
    add_index :subscription_plans, :is_free
    add_index :subscription_plans, :position
  end
end

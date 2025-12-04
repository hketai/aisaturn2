class AddFeaturesToSubscriptionPlans < ActiveRecord::Migration[7.1]
  def change
    return unless table_exists?(:subscription_plans)
    
    add_column :subscription_plans, :features, :jsonb unless column_exists?(:subscription_plans, :features)
    add_column :subscription_plans, :agent_limit, :integer unless column_exists?(:subscription_plans, :agent_limit)
    add_column :subscription_plans, :inbox_limit, :integer unless column_exists?(:subscription_plans, :inbox_limit)
    add_column :subscription_plans, :billing_cycle, :string unless column_exists?(:subscription_plans, :billing_cycle)
    add_column :subscription_plans, :trial_days, :integer unless column_exists?(:subscription_plans, :trial_days)
  end
end

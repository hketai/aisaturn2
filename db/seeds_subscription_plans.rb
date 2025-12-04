# Subscription Plans Seed
# Run with: rails runner db/seeds_subscription_plans.rb

puts 'Creating subscription plans...'

# Free Plan - Varsayılan ücretsiz plan
free_plan = SubscriptionPlan.find_or_create_by!(name: 'Ücretsiz') do |plan|
  plan.description = 'Başlangıç için ücretsiz plan'
  plan.price = 0.0
  plan.is_free = true
  plan.is_active = true
  plan.message_limit = 3000
  plan.conversation_limit = 300
  plan.agent_limit = 3
  plan.inbox_limit = 3
  plan.billing_cycle = 'monthly'
  plan.trial_days = 0
  plan.position = 1
end

# Update existing free plan if limits are different
free_plan.update!(
  message_limit: 3000,
  conversation_limit: 300,
  agent_limit: 3,
  inbox_limit: 3
)

puts "Created #{SubscriptionPlan.count} subscription plans"
puts "Plans: #{SubscriptionPlan.pluck(:name).join(', ')}"

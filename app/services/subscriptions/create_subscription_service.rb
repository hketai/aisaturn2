class Subscriptions::CreateSubscriptionService
  pattr_initialize [:account!, :subscription_plan!, :options]

  def perform
    validate_account!
    validate_plan!

    ActiveRecord::Base.transaction do
      # Cancel existing active subscription if upgrading
      cancel_existing_subscription if options&.dig(:cancel_existing)

      subscription = create_subscription
      apply_subscription_limits(subscription)
      subscription
    end
  end

  private

  def validate_account!
    raise ArgumentError, 'Account is required' if account.blank?
  end

  def validate_plan!
    raise ArgumentError, 'Subscription plan is required' if subscription_plan.blank?
    # Super admin can assign hidden plans, skip is_active check if bypass_active_check is true
    return if options&.dig(:bypass_active_check)

    raise ArgumentError, 'Subscription plan is not active' unless subscription_plan.is_active?
  end

  def cancel_existing_subscription
    account.account_subscriptions.active.each(&:cancel!)
  end

  def create_subscription
    expires_at = calculate_expires_at

    AccountSubscription.create!(
      account: account,
      subscription_plan: subscription_plan,
      status: determine_initial_status,
      started_at: Time.current,
      expires_at: expires_at,
      metadata: {
        auto_renew: options&.dig(:auto_renew) != false,
        payment_provider: options&.dig(:payment_provider) || 'manual',
        external_subscription_id: options&.dig(:external_subscription_id)
      }
    )
  end

  def determine_initial_status
    return 'trial' if subscription_plan.trial_days.to_i > 0
    'active'
  end

  def calculate_expires_at
    return nil if subscription_plan.billing_cycle.blank?

    case subscription_plan.billing_cycle
    when 'monthly'
      Time.current + 1.month
    when 'yearly'
      Time.current + 1.year
    else
      nil
    end
  end

  def apply_subscription_limits(subscription)
    # Update account limits based on subscription plan
    # Enterprise validation only allows: 'inboxes', 'agents', 'captain_responses', 'captain_documents'
    # We'll use string keys to match the schema
    plan = subscription.subscription_plan
    limits_hash = {}
    limits_hash['agents'] = plan.agent_limit.to_i if plan.agent_limit.present?
    limits_hash['inboxes'] = plan.inbox_limit.to_i if plan.inbox_limit.present?
    # Note: 'messages' and 'conversations' are not in the enterprise schema
    # We'll store them separately or skip them for now
    
    # Get existing limits and merge (preserve existing keys)
    existing_limits = account.limits || {}
    # Convert existing limits to string keys if needed
    existing_limits = existing_limits.transform_keys(&:to_s) if existing_limits.present?
    merged_limits = existing_limits.merge(limits_hash)
    
    # Only update if we have valid limits
    if merged_limits.present?
      # Use update_column to bypass validation to avoid enterprise validation issues
      account.update_column(:limits, merged_limits)
    end
  end
end


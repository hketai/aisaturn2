class SuperAdmin::AccountsController < SuperAdmin::ApplicationController
  # Overwrite any of the RESTful controller actions to implement custom behavior
  # For example, you may want to send an email after a foo is updated.
  #
  # def update
  #   super
  #   send_foo_updated_email(requested_resource)
  # end

  # Override this method to specify custom lookup behavior.
  # This will be used to set the resource for the `show`, `edit`, and `update`
  # actions.
  #
  # def find_resource(param)
  #   Foo.find_by!(slug: param)
  # end

  # The result of this lookup will be available as `requested_resource`

  # Override this if you have certain roles that require a subset
  # this will be used to set the records shown on the `index` action.
  #
  def scoped_resource
    resource_class.includes(account_subscriptions: :subscription_plan)
  end

  # Override `resource_params` if you want to transform the submitted
  # data before it's persisted. For example, the following would turn all
  # empty values into nil values. It uses other APIs such as `resource_class`
  # and `dashboard`:
  #
  def resource_params
    # Normal form submission - process all params
    permitted_params = super
    Rails.logger.info "Account resource_params - permitted_params keys: #{permitted_params.keys.inspect}"
    Rails.logger.info "Account resource_params - params[:account] keys: #{params[:account]&.keys.inspect}"
    Rails.logger.info "Account resource_params - params[:account][:subscription_plan_id]: #{params.dig(:account, :subscription_plan_id).inspect}"
    
    # Handle limits - ensure it's a valid hash
    if permitted_params[:limits].present? && permitted_params[:limits].is_a?(Hash)
      permitted_params[:limits] = permitted_params[:limits].compact
    elsif permitted_params[:limits].present? && permitted_params[:limits].respond_to?(:to_h)
      permitted_params[:limits] = permitted_params[:limits].to_h.compact
    elsif params[:account] && params[:account].key?(:limits)
      permitted_params[:limits] = {}
    end
    permitted_params[:selected_feature_flags] = params[:enabled_features].keys.map(&:to_sym) if params[:enabled_features].present?
    
    # Handle subscription plan assignment (from form)
    # Check both permitted_params and direct params
    plan_id = permitted_params[:subscription_plan_id] || params.dig(:account, :subscription_plan_id)
    Rails.logger.info "Subscription plan ID from permitted_params: #{permitted_params[:subscription_plan_id].inspect}"
    Rails.logger.info "Subscription plan ID from params[:account]: #{params.dig(:account, :subscription_plan_id).inspect}"
    Rails.logger.info "Final plan_id: #{plan_id.inspect}"
    
    if plan_id.present? && plan_id.to_s != '0' && plan_id.to_s != ''
      @subscription_plan_id = plan_id.to_i
      permitted_params.delete(:subscription_plan_id) # Remove from permitted_params so it doesn't try to save to Account model
      Rails.logger.info "Setting @subscription_plan_id to: #{@subscription_plan_id}"
    else
      Rails.logger.info "No subscription plan ID found or it's empty/zero (plan_id: #{plan_id.inspect})"
      @subscription_plan_id = nil
    end
    
    permitted_params
  end

  def create
    account = Account.new(resource_params)
    if account.save
      assign_subscription_plan(account) if @subscription_plan_id.present?
      redirect_to [namespace, account], notice: translate_with_resource('create.success')
    else
      render :new, locals: { page: Administrate::Page::Form.new(dashboard, account) }, status: :unprocessable_entity
    end
  end

  def update
    # Check if this is an inline subscription plan update
    is_inline_update = params[:account] && params[:account].key?(:subscription_plan_id) && !params[:account].key?(:limits) && !params[:account].key?(:name)
    
    if is_inline_update
      # For inline updates, extract subscription_plan_id directly from params
      plan_id = params.dig(:account, :subscription_plan_id)
      if plan_id.present?
        @subscription_plan_id = plan_id.to_i
        Rails.logger.info "Inline update: Setting subscription_plan_id to #{@subscription_plan_id}"
        assign_subscription_plan(requested_resource)
        redirect_to [namespace, :accounts], notice: 'Subscription plan updated successfully'
      else
        redirect_to [namespace, :accounts], alert: 'No subscription plan selected'
      end
    else
      # Normal form submission - resource_params will set @subscription_plan_id
      Rails.logger.info "Account update - @subscription_plan_id before update: #{@subscription_plan_id.inspect}"
      
      # Get subscription_plan_id from params before calling resource_params
      # because resource_params might delete it from permitted_params
      form_plan_id = params.dig(:account, :subscription_plan_id) || params[:account_subscription_plan_id]
      Rails.logger.info "Form subscription_plan_id from params: #{form_plan_id.inspect}"
      
      if requested_resource.update(resource_params)
        Rails.logger.info "Account update successful - @subscription_plan_id: #{@subscription_plan_id.inspect}"
        
        # Try to get plan_id from @subscription_plan_id or form params
        plan_id_to_assign = @subscription_plan_id || (form_plan_id.present? && form_plan_id.to_i > 0 ? form_plan_id.to_i : nil)
        
        if plan_id_to_assign.present?
          Rails.logger.info "Calling assign_subscription_plan with plan_id: #{plan_id_to_assign}"
          @subscription_plan_id = plan_id_to_assign
          assign_subscription_plan(requested_resource)
        else
          Rails.logger.info "No subscription plan ID to assign (form_plan_id: #{form_plan_id.inspect}, @subscription_plan_id: #{@subscription_plan_id.inspect})"
        end
        redirect_to [namespace, requested_resource], notice: translate_with_resource('update.success')
      else
        Rails.logger.error "Account update failed: #{requested_resource.errors.full_messages.inspect}"
        render :edit, locals: { page: Administrate::Page::Form.new(dashboard, requested_resource) }, status: :unprocessable_entity
      end
    end
  rescue StandardError => e
    Rails.logger.error "Account update error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    redirect_to [namespace, is_inline_update ? :accounts : requested_resource], alert: "Update failed: #{e.message}"
  end

  private

  def assign_subscription_plan(account)
    Rails.logger.info "=== assign_subscription_plan called ==="
    Rails.logger.info "@subscription_plan_id: #{@subscription_plan_id.inspect}"
    
    return if @subscription_plan_id.blank?

    begin
      plan = SubscriptionPlan.find(@subscription_plan_id)
      Rails.logger.info "Found plan: #{plan.name} (ID: #{plan.id})"
      Rails.logger.info "Assigning plan #{plan.name} (ID: #{plan.id}) to account #{account.id}"
      
      # Reload account to ensure we have latest data
      account.reload
      
      # Cancel existing active and trial subscriptions
      active_subscriptions = account.account_subscriptions.where(status: ['active', 'trial'])
      canceled_count = active_subscriptions.count
      Rails.logger.info "Found #{canceled_count} active/trial subscriptions to cancel"
      
      active_subscriptions.each do |sub|
        Rails.logger.info "Canceling subscription ID: #{sub.id}, Status: #{sub.status}, Plan: #{sub.subscription_plan.name}"
        sub.cancel!
      end
      Rails.logger.info "Canceled #{canceled_count} existing subscriptions"
      
      # Create new subscription
      Rails.logger.info "Creating new subscription..."
      subscription = nil
      ActiveRecord::Base.transaction do
        subscription = Subscriptions::CreateSubscriptionService.new(
          account: account,
          subscription_plan: plan,
          options: {
            auto_renew: true,
            cancel_existing: false, # Already canceled above
            bypass_active_check: true # Super admin can assign hidden plans
          }
        ).perform
        
        Rails.logger.info "Subscription created: ID=#{subscription.id}, Status=#{subscription.status}, Plan=#{subscription.subscription_plan.name}"
        
        # Update limits manually with proper validation
        plan_obj = subscription.subscription_plan
        # Enterprise validation only allows: 'inboxes', 'agents', 'captain_responses', 'captain_documents'
        limits_hash = {}
        limits_hash['agents'] = plan_obj.agent_limit.to_i if plan_obj.agent_limit.present?
        limits_hash['inboxes'] = plan_obj.inbox_limit.to_i if plan_obj.inbox_limit.present?
        
        # Get existing limits and merge (preserve existing keys)
        existing_limits = account.limits || {}
        existing_limits = existing_limits.transform_keys(&:to_s) if existing_limits.present?
        merged_limits = existing_limits.merge(limits_hash)
        
        # Only update if we have valid limits
        if merged_limits.present?
          account.update_column(:limits, merged_limits)
          Rails.logger.info "Updated account limits: #{merged_limits.inspect}"
        end
      end
      
      # Force reload account and clear any cached associations
      account.reload
      account.account_subscriptions.reload
      
      # Verify subscription was created
      current = account.current_subscription
      if current
        Rails.logger.info "✓ Current subscription verified: ID=#{current.id}, Plan=#{current.subscription_plan.name}, Status=#{current.status}"
      else
        Rails.logger.error "✗ ERROR: Subscription created but current_subscription is nil!"
        Rails.logger.error "All subscriptions: #{account.account_subscriptions.pluck(:id, :status, :subscription_plan_id, :expires_at).inspect}"
      end
      
      subscription
    rescue StandardError => e
      Rails.logger.error "✗✗✗ Failed to assign subscription plan: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      # Don't raise - let the update succeed even if subscription assignment fails
      # But log it so we can debug
      nil
    end
  end

  # See https://administrate-prototype.herokuapp.com/customizing_controller_actions
  # for more information

  def seed
    Internal::SeedAccountJob.perform_later(requested_resource)
    # rubocop:disable Rails/I18nLocaleTexts
    redirect_back(fallback_location: [namespace, requested_resource], notice: 'Account seeding triggered')
    # rubocop:enable Rails/I18nLocaleTexts
  end

  def reset_cache
    requested_resource.reset_cache_keys
    # rubocop:disable Rails/I18nLocaleTexts
    redirect_back(fallback_location: [namespace, requested_resource], notice: 'Cache keys cleared')
    # rubocop:enable Rails/I18nLocaleTexts
  end

  def destroy
    account = Account.find(params[:id])

    DeleteObjectJob.perform_later(account) if account.present?
    # rubocop:disable Rails/I18nLocaleTexts
    redirect_back(fallback_location: [namespace, requested_resource], notice: 'Account deletion is in progress.')
    # rubocop:enable Rails/I18nLocaleTexts
  end
end

SuperAdmin::AccountsController.prepend_mod_with('SuperAdmin::AccountsController')

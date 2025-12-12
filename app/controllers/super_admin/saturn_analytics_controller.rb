class SuperAdmin::SaturnAnalyticsController < SuperAdmin::ApplicationController
  def index
    period = params[:period]&.to_sym || :this_month

    @summary = Saturn::ApiUsageTrackerService.dashboard_summary(period: period)
    @daily_trend = Saturn::ApiUsageTrackerService.daily_trend(days: 30)
    @account_usage = Saturn::ApiUsageTrackerService.account_usage_stats(limit: 10)
    @model_usage = Saturn::ApiUsageTrackerService.model_usage_stats
    @assistant_performance = Saturn::ApiUsageTrackerService.assistant_performance_stats(limit: 10)
    @system_health = Saturn::ApiUsageTrackerService.system_health_stats

    # Ek istatistikler
    @total_assistants = Saturn::Assistant.count
    @active_assistants = Saturn::Assistant.joins(:saturn_inboxes).distinct.count
    @total_faqs = Saturn::AssistantResponse.count
    @total_documents = Saturn::Document.count
    @faqs_with_embedding = Saturn::AssistantResponse.where.not(embedding: nil).count
    @chunks_with_embedding = Saturn::DocumentChunk.where.not(embedding: nil).count if defined?(Saturn::DocumentChunk)
  end
end


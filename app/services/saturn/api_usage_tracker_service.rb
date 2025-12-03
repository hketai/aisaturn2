class Saturn::ApiUsageTrackerService
  class << self
    # Chat API kullanımını kaydet
    def track_chat(params)
      create_usage_record(
        api_type: 'chat',
        **params
      )
    end

    # Embedding API kullanımını kaydet
    def track_embedding(params)
      create_usage_record(
        api_type: 'embedding',
        cache_hit: params[:cache_hit] || false,
        **params.except(:cache_hit)
      )
    end

    # Hata kaydet
    def track_error(params)
      create_usage_record(
        has_error: true,
        error_type: params[:error_type],
        **params.except(:error_type)
      )
    end

    # Dashboard için özet istatistikler
    def dashboard_summary(period: :this_month)
      scope = case period
              when :today
                Saturn::ApiUsage.today
              when :this_week
                Saturn::ApiUsage.this_week
              when :this_month
                Saturn::ApiUsage.this_month
              else
                Saturn::ApiUsage.all
              end

      chat_scope = scope.chat_api
      embedding_scope = scope.embedding_api

      {
        overview: {
          total_requests: scope.count,
          total_cost: scope.total_cost.to_f.round(4),
          total_tokens: scope.total_tokens,
          avg_response_time: scope.average_response_time&.round(2)
        },
        chat: {
          requests: chat_scope.count,
          input_tokens: chat_scope.sum(:input_tokens),
          output_tokens: chat_scope.sum(:output_tokens),
          cost: chat_scope.total_cost.to_f.round(4)
        },
        embedding: {
          requests: embedding_scope.count,
          tokens: embedding_scope.sum(:input_tokens),
          cost: embedding_scope.total_cost.to_f.round(4),
          cache_hit_rate: embedding_scope.cache_hit_rate
        },
        quality: {
          confidence_distribution: scope.confidence_distribution,
          hallucination_distribution: scope.hallucination_risk_distribution,
          no_info_rate: calculate_no_info_rate(scope),
          error_rate: scope.error_rate
        }
      }
    end

    # Hesap bazlı kullanım
    def account_usage_stats(limit: 10)
      Saturn::ApiUsage.this_month
                      .by_account_stats
                      .limit(limit)
                      .map do |stat|
        {
          account_id: stat.account_id,
          account_name: stat.account_name,
          request_count: stat.request_count,
          total_tokens: stat.total_tokens,
          total_cost: stat.total_cost.to_f.round(4),
          cache_hit_rate: account_cache_hit_rate(stat.account_id)
        }
      end
    end

    # Günlük trend verileri
    def daily_trend(days: 30)
      Saturn::ApiUsage.where(created_at: days.days.ago..Time.current)
                      .group_by_day(:created_at)
                      .sum(:cost)
                      .map { |date, cost| [date.to_s, cost.to_f.round(4)] }
    end

    # Model bazlı kullanım
    def model_usage_stats
      Saturn::ApiUsage.this_month
                      .by_model_stats
                      .map do |stat|
        {
          model: stat.model || 'unknown',
          request_count: stat.request_count,
          input_tokens: stat.total_input_tokens,
          output_tokens: stat.total_output_tokens,
          cost: stat.total_cost.to_f.round(4)
        }
      end
    end

    # Asistan performans istatistikleri
    def assistant_performance_stats(limit: 10)
      Saturn::ApiUsage.this_month
                      .where.not(saturn_assistant_id: nil)
                      .joins('INNER JOIN saturn_assistants ON saturn_assistants.id = saturn_api_usages.saturn_assistant_id')
                      .joins('INNER JOIN accounts ON accounts.id = saturn_assistants.account_id')
                      .group('saturn_assistants.id', 'saturn_assistants.name', 'accounts.name')
                      .select(
                        'saturn_assistants.id as assistant_id',
                        'saturn_assistants.name as assistant_name',
                        'accounts.name as account_name',
                        'COUNT(*) as message_count',
                        'SUM(saturn_api_usages.cost) as total_cost',
                        'AVG(saturn_api_usages.response_time) as avg_response_time'
                      )
                      .order('message_count DESC')
                      .limit(limit)
                      .map do |stat|
        no_info_count = Saturn::ApiUsage.where(saturn_assistant_id: stat.assistant_id, no_info_response: true).count
        no_info_rate = stat.message_count.positive? ? (no_info_count.to_f / stat.message_count * 100).round(1) : 0

        {
          assistant_id: stat.assistant_id,
          assistant_name: stat.assistant_name,
          account_name: stat.account_name,
          message_count: stat.message_count,
          total_cost: stat.total_cost.to_f.round(4),
          avg_response_time: stat.avg_response_time&.round(2),
          no_info_rate: no_info_rate
        }
      end
    end

    # Sistem sağlığı metrikleri
    def system_health_stats
      last_24h = Saturn::ApiUsage.where(created_at: 24.hours.ago..Time.current)

      {
        response_times: {
          chat_avg: last_24h.chat_api.average(:response_time)&.round(2),
          embedding_avg: last_24h.embedding_api.average(:response_time)&.round(2)
        },
        errors: {
          total: last_24h.with_errors.count,
          rate: last_24h.error_rate,
          by_type: last_24h.with_errors.group(:error_type).count
        },
        hallucination: {
          high: last_24h.where(hallucination_risk: 'high').count,
          medium: last_24h.where(hallucination_risk: 'medium').count,
          low: last_24h.where(hallucination_risk: 'low').count
        }
      }
    end

    private

    def create_usage_record(params)
      # Maliyet hesapla
      if params[:model].present? && params[:cost].blank?
        params[:cost] = Saturn::ApiUsage.calculate_cost(
          params[:model],
          params[:input_tokens] || 0,
          params[:output_tokens] || 0
        )
      end

      Saturn::ApiUsage.create!(params)
    rescue StandardError => e
      Rails.logger.error "[SATURN API USAGE] Failed to track usage: #{e.message}"
      nil
    end

    def calculate_no_info_rate(scope)
      total = scope.count
      return 0 if total.zero?

      (scope.where(no_info_response: true).count.to_f / total * 100).round(2)
    end

    def account_cache_hit_rate(account_id)
      scope = Saturn::ApiUsage.this_month.embedding_api.where(account_id: account_id)
      total = scope.count
      return 0 if total.zero?

      (scope.cache_hits.count.to_f / total * 100).round(1)
    end
  end
end


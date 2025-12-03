class Saturn::ApiUsage < ApplicationRecord
  self.table_name = 'saturn_api_usages'

  belongs_to :account, optional: true
  belongs_to :saturn_assistant, class_name: 'Saturn::Assistant', optional: true

  validates :api_type, presence: true, inclusion: { in: %w[chat embedding] }

  scope :chat_api, -> { where(api_type: 'chat') }
  scope :embedding_api, -> { where(api_type: 'embedding') }
  scope :with_errors, -> { where(has_error: true) }
  scope :successful, -> { where(has_error: false) }
  scope :cache_hits, -> { where(cache_hit: true) }
  scope :cache_misses, -> { where(cache_hit: false) }
  scope :today, -> { where(created_at: Time.current.beginning_of_day..Time.current.end_of_day) }
  scope :this_week, -> { where(created_at: 1.week.ago..Time.current) }
  scope :this_month, -> { where(created_at: 1.month.ago..Time.current) }

  # Model bazlı maliyet hesaplama sabitleri (USD per 1K token)
  PRICING = {
    'gpt-4o' => { input: 0.005, output: 0.015 },
    'gpt-4o-mini' => { input: 0.00015, output: 0.0006 },
    'gpt-4-turbo' => { input: 0.01, output: 0.03 },
    'gpt-3.5-turbo' => { input: 0.0005, output: 0.0015 },
    'text-embedding-3-small' => { input: 0.00002, output: 0 },
    'text-embedding-3-large' => { input: 0.00013, output: 0 },
    'text-embedding-ada-002' => { input: 0.0001, output: 0 }
  }.freeze

  def self.calculate_cost(model, input_tokens, output_tokens = 0)
    pricing = PRICING[model] || PRICING['gpt-4o']
    input_cost = (input_tokens.to_f / 1000) * pricing[:input]
    output_cost = (output_tokens.to_f / 1000) * pricing[:output]
    input_cost + output_cost
  end

  # Aggregation methods
  def self.total_cost
    sum(:cost)
  end

  def self.total_tokens
    sum(:input_tokens) + sum(:output_tokens)
  end

  def self.average_response_time
    average(:response_time)
  end

  def self.cache_hit_rate
    total = count
    return 0 if total.zero?

    (cache_hits.count.to_f / total * 100).round(2)
  end

  def self.error_rate
    total = count
    return 0 if total.zero?

    (with_errors.count.to_f / total * 100).round(2)
  end

  def self.confidence_distribution
    group(:confidence).count
  end

  def self.hallucination_risk_distribution
    group(:hallucination_risk).count
  end

  def self.daily_stats(days = 30)
    where(created_at: days.days.ago..Time.current)
      .group_by_day(:created_at)
      .select(
        'DATE(created_at) as date',
        'COUNT(*) as request_count',
        'SUM(input_tokens) as total_input_tokens',
        'SUM(output_tokens) as total_output_tokens',
        'SUM(cost) as total_cost',
        'AVG(response_time) as avg_response_time'
      )
  end

  def self.by_account_stats
    joins(:account)
      .group('accounts.id', 'accounts.name')
      .select(
        'accounts.id as account_id',
        'accounts.name as account_name',
        'COUNT(*) as request_count',
        'SUM(saturn_api_usages.input_tokens + saturn_api_usages.output_tokens) as total_tokens',
        'SUM(saturn_api_usages.cost) as total_cost'
      )
      .order('total_cost DESC')
  end

  def self.by_model_stats
    group(:model)
      .select(
        'model',
        'COUNT(*) as request_count',
        'SUM(input_tokens) as total_input_tokens',
        'SUM(output_tokens) as total_output_tokens',
        'SUM(cost) as total_cost'
      )
      .order('total_cost DESC')
  end
end


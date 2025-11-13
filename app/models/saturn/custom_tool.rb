# == Schema Information
#
# Table name: saturn_custom_tools
#
#  id                :bigint           not null, primary key
#  auth_config       :jsonb
#  auth_type         :string           default("none")
#  description       :text
#  enabled           :boolean          default(TRUE), not null
#  endpoint_url      :text             not null
#  http_method       :string           default("GET"), not null
#  param_schema      :jsonb
#  request_template  :text
#  response_template :text
#  slug              :string           not null
#  title             :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint           not null
#
# Indexes
#
#  index_saturn_custom_tools_on_account_id           (account_id)
#  index_saturn_custom_tools_on_account_id_and_slug  (account_id,slug) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class Saturn::CustomTool < ApplicationRecord
  self.table_name = 'saturn_custom_tools'

  # Associations
  belongs_to :account

  # Validations - different order
  validates :account_id, presence: true
  validates :slug, presence: true, uniqueness: { scope: :account_id }, format: { with: /\A[a-z0-9_-]+\z/ }
  validates :title, presence: true
  validates :endpoint_url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }
  validates :http_method, presence: true, inclusion: { in: %w[GET POST PUT PATCH DELETE] }

  # Scopes - different organization
  scope :for_account, ->(account_id) { where(account_id: account_id) }
  scope :enabled, -> { where(enabled: true) }
  scope :disabled, -> { where(enabled: false) }
  scope :by_method, ->(method) { where(http_method: method) }

  # Public methods
  def as_tool_definition
    {
      id: slug,
      name: title,
      description: description,
      type: 'custom',
      http_method: http_method,
      endpoint_url: endpoint_url,
      request_template: request_template,
      response_template: response_template,
      auth_type: auth_type,
      auth_config: auth_config || {},
      param_schema: param_schema || []
    }
  end

  def is_enabled?
    enabled?
  end

  def authentication_config
    auth_config || {}
  end

  def parameter_schema
    param_schema || []
  end
end

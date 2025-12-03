# == Schema Information
#
# Table name: saturn_assistants
#
#  id                  :bigint           not null, primary key
#  config              :jsonb            not null
#  description         :string
#  guardrails          :jsonb
#  name                :string           not null
#  response_guidelines :jsonb
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#
# Indexes
#
#  index_saturn_assistants_on_account_id           (account_id)
#  index_saturn_assistants_on_account_id_and_name  (account_id,name) UNIQUE
#
class Saturn::Assistant < ApplicationRecord
  include Avatarable

  self.table_name = 'saturn_assistants'

  # Associations organized differently
  belongs_to :account
  has_many :scenarios, class_name: 'Saturn::Scenario', dependent: :destroy_async
  has_many :responses, class_name: 'Saturn::AssistantResponse', dependent: :destroy_async
  has_many :documents, class_name: 'Saturn::Document', dependent: :destroy_async
  has_many :saturn_inboxes, class_name: 'SaturnInbox', foreign_key: :saturn_assistant_id, dependent: :destroy_async
  has_many :inboxes, through: :saturn_inboxes
  has_many :messages, as: :sender, dependent: :nullify
  has_many :assistant_integrations, class_name: 'Saturn::AssistantIntegration', foreign_key: :saturn_assistant_id, dependent: :destroy

  # Config accessors
  store_accessor :config, :temperature, :feature_faq, :feature_memory, :feature_citation, :product_name, :working_hours, :handoff_config, :sector

  # Validations - different order and approach
  validates :account_id, presence: true
  validates :name, presence: true, uniqueness: { scope: :account_id }
  validates :description, presence: true

  # Scopes - different organization
  scope :for_account, ->(account_id) { where(account_id: account_id) }
  scope :ordered, -> { order(created_at: :desc) }
  scope :recent, -> { order(updated_at: :desc) }

  # Public methods
  def display_name
    name
  end

  def event_payload
    {
      id: id,
      name: name,
      description: description
    }
  end

  def configuration
    config || {}
  end

  def active_scenarios
    scenarios.enabled
  end

  def document_count
    documents.count
  end

  def response_count
    responses.count
  end

  def push_event_data
    {
      id: id,
      name: name,
      avatar_url: avatar_url,
      type: 'saturn_assistant'
    }
  end

  def webhook_data
    {
      id: id,
      name: name,
      type: 'saturn_assistant'
    }
  end

  # Integration helpers
  def integration_enabled?(integration_type)
    integration = assistant_integrations.find_by(integration_type: integration_type)
    # Eğer kayıt yoksa, varsayılan olarak disabled kabul et
    return false if integration.nil?

    integration.enabled?
  end

  def shopify_enabled?
    integration_enabled?('shopify')
  end

  def enable_integration!(integration_type)
    integration = assistant_integrations.find_or_initialize_by(integration_type: integration_type)
    integration.update!(enabled: true)
  end

  def disable_integration!(integration_type)
    integration = assistant_integrations.find_by(integration_type: integration_type)
    integration&.update!(enabled: false)
  end

  def toggle_integration!(integration_type)
    integration = assistant_integrations.find_or_initialize_by(integration_type: integration_type)
    integration.update!(enabled: !integration.enabled?)
    integration.enabled?
  end

  def enabled_integrations
    assistant_integrations.enabled.pluck(:integration_type)
  end
end

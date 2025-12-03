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

  # Config accessors
  store_accessor :config, :temperature, :feature_faq, :feature_memory, :feature_citation, :product_name, :working_hours, :handoff_config

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
end

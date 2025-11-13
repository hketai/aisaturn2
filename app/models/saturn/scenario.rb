# == Schema Information
#
# Table name: saturn_scenarios
#
#  id           :bigint           not null, primary key
#  description  :text
#  enabled      :boolean          default(TRUE), not null
#  instruction  :text
#  title        :string
#  tools        :jsonb
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#  assistant_id :bigint           not null
#
# Indexes
#
#  index_saturn_scenarios_on_account_id                (account_id)
#  index_saturn_scenarios_on_assistant_id              (assistant_id)
#  index_saturn_scenarios_on_assistant_id_and_enabled  (assistant_id,enabled)
#  index_saturn_scenarios_on_enabled                   (enabled)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (assistant_id => saturn_assistants.id)
#
class Saturn::Scenario < ApplicationRecord
  self.table_name = 'saturn_scenarios'

  # Associations
  belongs_to :account
  belongs_to :assistant, class_name: 'Saturn::Assistant'

  # Validations - different order
  validates :assistant_id, presence: true
  validates :account_id, presence: true
  validates :title, presence: true
  validates :description, presence: true
  validates :instruction, presence: true

  # Scopes
  scope :enabled, -> { where(enabled: true) }
  scope :disabled, -> { where(enabled: false) }
  scope :for_assistant, ->(assistant_id) { where(assistant_id: assistant_id) }

  # Delegations - different approach
  delegate :temperature, to: :assistant
  delegate :feature_faq, to: :assistant
  delegate :feature_memory, to: :assistant
  delegate :product_name, to: :assistant
  delegate :response_guidelines, to: :assistant
  delegate :guardrails, to: :assistant

  # Public methods
  def context_for_prompt
    {
      title: title,
      instructions: instruction,
      tools: tools || [],
      assistant_name: normalize_assistant_name,
      response_guidelines: response_guidelines || [],
      guardrails: guardrails || []
    }
  end

  def is_enabled?
    enabled?
  end

  def tool_list
    tools || []
  end

  private

  def normalize_assistant_name
    assistant.name.downcase.gsub(/\s+/, '_')
  end
end

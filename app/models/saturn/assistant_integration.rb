# == Schema Information
#
# Table name: saturn_assistant_integrations
#
#  id                   :bigint           not null, primary key
#  enabled              :boolean          default(TRUE), not null
#  integration_type     :string           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  saturn_assistant_id  :bigint           not null
#
# Indexes
#
#  idx_saturn_asst_integrations_unique                       (saturn_assistant_id,integration_type) UNIQUE
#  index_saturn_assistant_integrations_on_integration_type   (integration_type)
#  index_saturn_assistant_integrations_on_saturn_assistant_id (saturn_assistant_id)
#
# Foreign Keys
#
#  fk_rails_...  (saturn_assistant_id => saturn_assistants.id) ON DELETE => cascade
#
class Saturn::AssistantIntegration < ApplicationRecord
  self.table_name = 'saturn_assistant_integrations'

  INTEGRATION_TYPES = %w[shopify ikas].freeze

  belongs_to :assistant, class_name: 'Saturn::Assistant', foreign_key: :saturn_assistant_id

  validates :integration_type, presence: true, 
                               inclusion: { in: INTEGRATION_TYPES },
                               uniqueness: { scope: :saturn_assistant_id }

  scope :enabled, -> { where(enabled: true) }
  scope :for_type, ->(type) { where(integration_type: type) }
end


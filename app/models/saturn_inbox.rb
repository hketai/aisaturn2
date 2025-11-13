# == Schema Information
#
# Table name: saturn_inboxes
#
#  id                  :bigint           not null, primary key
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  inbox_id            :bigint           not null
#  saturn_assistant_id :bigint           not null
#
# Indexes
#
#  index_saturn_inboxes_on_inbox_id                          (inbox_id)
#  index_saturn_inboxes_on_saturn_assistant_id               (saturn_assistant_id)
#  index_saturn_inboxes_on_saturn_assistant_id_and_inbox_id  (saturn_assistant_id,inbox_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (inbox_id => inboxes.id)
#  fk_rails_...  (saturn_assistant_id => saturn_assistants.id)
#
class SaturnInbox < ApplicationRecord
  self.table_name = 'saturn_inboxes'

  belongs_to :saturn_assistant, class_name: 'Saturn::Assistant', foreign_key: :saturn_assistant_id
  belongs_to :inbox

  validates :saturn_assistant_id, uniqueness: { scope: :inbox_id }

  after_create :create_saturn_hook
  after_destroy :destroy_saturn_hook

  private

  def create_saturn_hook
    # Create hook for Saturn integration
    Integrations::Hook.find_or_create_by!(
      app_id: 'saturn',
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      hook_type: 'inbox'
    ) do |hook|
      hook.settings = { assistant_id: saturn_assistant_id }
    end
  end

  def destroy_saturn_hook
    # Destroy hook when SaturnInbox is destroyed
    Integrations::Hook.where(
      app_id: 'saturn',
      account_id: inbox.account_id,
      inbox_id: inbox.id
    ).destroy_all
  end
end


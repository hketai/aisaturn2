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
end


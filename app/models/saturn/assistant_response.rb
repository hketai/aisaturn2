# == Schema Information
#
# Table name: saturn_assistant_responses
#
#  id                :bigint           not null, primary key
#  answer            :text             not null
#  documentable_type :string
#  embedding         :vector(1536)
#  question          :string           not null
#  status            :integer          default("approved"), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint           not null
#  assistant_id      :bigint           not null
#  documentable_id   :bigint
#
# Indexes
#
#  idx_saturn_asst_resp_on_documentable              (documentable_id,documentable_type)
#  index_saturn_assistant_responses_on_account_id    (account_id)
#  index_saturn_assistant_responses_on_assistant_id  (assistant_id)
#  index_saturn_assistant_responses_on_status        (status)
#  vector_idx_saturn_knowledge_entries_embedding     (embedding) USING ivfflat
#
class Saturn::AssistantResponse < ApplicationRecord
  self.table_name = 'saturn_assistant_responses'

  # Associations - different order
  belongs_to :account
  belongs_to :assistant, class_name: 'Saturn::Assistant'
  belongs_to :documentable, polymorphic: true, optional: true
  has_neighbors :embedding, normalize: true

  # Status enum
  enum status: { pending: 0, approved: 1 }

  # Validations
  validates :question, presence: true
  validates :answer, presence: true
  validates :assistant_id, presence: true
  validates :account_id, presence: true

  # Callbacks - different order
  before_validation :set_default_status
  before_validation :link_to_assistant_account

  # Scopes - different organization
  scope :by_account, ->(account_id) { where(account_id: account_id) }
  scope :by_assistant, ->(assistant_id) { where(assistant_id: assistant_id) }
  scope :ordered, -> { order(created_at: :desc) }
  scope :approved_only, -> { where(status: :approved) }
  scope :pending_only, -> { where(status: :pending) }

  # Class methods
  def self.find_by_query(search_term)
    where('question ILIKE ? OR answer ILIKE ?', "%#{search_term}%", "%#{search_term}%")
  end

  def self.find_similar_questions(query_text)
    # Vector search will be implemented in service layer
    find_by_query(query_text).limit(10)
  end

  private

  def set_default_status
    self.status ||= :approved
  end

  def link_to_assistant_account
    self.account = assistant&.account if account_id.blank? && assistant.present?
  end
end

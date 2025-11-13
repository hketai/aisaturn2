class AddStatusToSaturnDocuments < ActiveRecord::Migration[7.0]
  def change
    add_column :saturn_documents, :status, :integer, null: false, default: 0
    add_index :saturn_documents, :status
  end
end


class AddMetadataToSaturnDocuments < ActiveRecord::Migration[7.1]
  def change
    add_column :saturn_documents, :metadata, :jsonb, default: {}
  end
end


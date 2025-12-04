class CreateSaturnDocumentChunks < ActiveRecord::Migration[7.0]
  def change
    create_table :saturn_document_chunks do |t|
      t.references :document, null: false, foreign_key: { to_table: :saturn_documents, on_delete: :cascade }
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.text :content, null: false
      t.integer :chunk_index, default: 0
      t.vector :embedding, limit: 1536

      t.timestamps
    end

    add_index :saturn_document_chunks, :chunk_index
    add_index :saturn_document_chunks, :embedding, using: :ivfflat, opclass: :vector_cosine_ops, name: 'idx_saturn_doc_chunks_embedding'
  end
end


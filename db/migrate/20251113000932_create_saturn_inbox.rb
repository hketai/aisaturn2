class CreateSaturnInbox < ActiveRecord::Migration[7.0]
  def change
    create_table :saturn_inboxes do |t|
      t.references :saturn_assistant, null: false, foreign_key: { to_table: :saturn_assistants }
      t.references :inbox, null: false, foreign_key: true
      t.timestamps
    end

    add_index :saturn_inboxes, [:saturn_assistant_id, :inbox_id], unique: true
  end
end


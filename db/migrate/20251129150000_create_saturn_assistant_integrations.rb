class CreateSaturnAssistantIntegrations < ActiveRecord::Migration[7.0]
  def change
    create_table :saturn_assistant_integrations do |t|
      t.bigint :saturn_assistant_id, null: false
      t.string :integration_type, null: false
      t.boolean :enabled, default: true, null: false
      t.timestamps
    end

    add_index :saturn_assistant_integrations, [:saturn_assistant_id, :integration_type], 
              unique: true, 
              name: 'idx_saturn_asst_integrations_unique'
    add_index :saturn_assistant_integrations, :saturn_assistant_id
    add_index :saturn_assistant_integrations, :integration_type

    add_foreign_key :saturn_assistant_integrations, :saturn_assistants, 
                    column: :saturn_assistant_id, 
                    on_delete: :cascade
  end
end


class CreateSaturnScenarios < ActiveRecord::Migration[7.1]
  def change
    create_table :saturn_scenarios do |t|
      t.string :title
      t.text :description
      t.text :instruction
      t.jsonb :tools, default: []
      t.boolean :enabled, default: true, null: false
      t.references :assistant, null: false, foreign_key: { to_table: :saturn_assistants }
      t.references :account, null: false, foreign_key: true

      t.timestamps
    end

    add_index :saturn_scenarios, :enabled
    add_index :saturn_scenarios, [:assistant_id, :enabled]
  end
end


class AddSectorToSaturnAssistants < ActiveRecord::Migration[7.0]
  def change
    add_column :saturn_assistants, :sector, :string
    add_index :saturn_assistants, :sector
  end
end


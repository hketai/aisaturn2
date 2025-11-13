class AddConfigToSaturnAssistant < ActiveRecord::Migration[7.0]
  def change
    add_column :saturn_assistants, :config, :jsonb, default: {}, null: false
  end
end


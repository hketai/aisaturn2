class AddResponseGuidelinesAndGuardrailsToSaturnAssistant < ActiveRecord::Migration[7.1]
  def change
    add_column :saturn_assistants, :response_guidelines, :jsonb, default: []
    add_column :saturn_assistants, :guardrails, :jsonb, default: []
  end
end


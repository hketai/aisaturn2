class CreateSaturnApiUsages < ActiveRecord::Migration[7.0]
  def change
    create_table :saturn_api_usages do |t|
      t.references :account, foreign_key: true, index: true
      t.references :saturn_assistant, foreign_key: true, index: true

      # API türü ve model bilgisi
      t.string :api_type, null: false # 'chat', 'embedding'
      t.string :model # 'gpt-4o', 'text-embedding-3-small', etc.

      # Token bilgileri
      t.integer :input_tokens, default: 0
      t.integer :output_tokens, default: 0
      t.decimal :cost, precision: 12, scale: 8, default: 0

      # Performans
      t.float :response_time # saniye
      t.boolean :cache_hit, default: false

      # Kalite metrikleri
      t.string :confidence # 'high', 'medium', 'low'
      t.string :hallucination_risk # 'high', 'medium', 'low'
      t.boolean :no_info_response, default: false # "bilmiyorum" yanıtı?

      # Hata bilgisi
      t.boolean :has_error, default: false
      t.string :error_type

      t.timestamps
    end

    add_index :saturn_api_usages, :api_type
    add_index :saturn_api_usages, :created_at
    add_index :saturn_api_usages, [:account_id, :created_at]
  end
end


class CreateChannelWhatsappWeb < ActiveRecord::Migration[7.1]
  def change
    create_table :channel_whatsapp_webs do |t|
      t.references :account, null: false, foreign_key: true
      t.string :phone_number
      t.string :status, default: 'disconnected'
      t.jsonb :provider_config, default: {}
      t.text :auth_data_encrypted
      t.string :cache_storage_path
      t.string :qr_code_token
      t.datetime :qr_code_expires_at

      t.timestamps
    end

    add_index :channel_whatsapp_webs, :phone_number, unique: true
    add_index :channel_whatsapp_webs, :qr_code_token, unique: true
    # account_id index is automatically created by t.references
  end
end

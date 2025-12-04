class UpdateAisaturnBranding < ActiveRecord::Migration[7.1]
  def up
    # AISATURN branding config'lerini her zaman güncelle
    # Bu migration her çalıştığında branding değerlerini AISATURN'a ayarlar
    # Chatwoot logolarının geri gelmesini önlemek için zorla güncelle
    
    branding_configs = {
      'INSTALLATION_NAME' => 'AISATURN',
      'BRAND_NAME' => '',
      'BRAND_URL' => 'https://aisaturn.co',
      'WIDGET_BRAND_URL' => 'https://aisaturn.co',
      'LOGO' => '/brand-assets/logo.png', # Açık tema: aisaturnkoyu.png
      'LOGO_DARK' => '/brand-assets/logo_dark.png', # Koyu tema: beyaz.png
      'LOGO_THUMBNAIL' => '/brand-assets/logo.png'
    }
    
    branding_configs.each do |name, value|
      config = InstallationConfig.find_by(name: name)
      if config
        # Mevcut değer farklıysa veya Chatwoot değeri varsa güncelle
        current_value = config.value
        should_update = current_value != value || 
                       current_value.to_s.downcase.include?('chatwoot') ||
                       current_value.to_s.include?('logo.svg') ||
                       current_value.to_s.include?('logo_thumbnail.svg')
        
        if should_update
          config.update!(value: value, locked: true)
          Rails.logger.info "AISATURN Branding Migration: Updated #{name} from '#{current_value}' to '#{value}'"
        end
      else
        InstallationConfig.create!(name: name, value: value, locked: true)
        Rails.logger.info "AISATURN Branding Migration: Created #{name} with value '#{value}'"
      end
    end
    
    # Cache'i temizle
    begin
      GlobalConfig.clear_cache
    rescue StandardError => e
      Rails.logger.warn "AISATURN Branding Migration: Could not clear cache: #{e.message}"
    end
  end
  
  def down
    # Geri alma işlemi yapılmıyor - branding config'leri AISATURN'da kalmalı
    # Bu migration'ın down metodu boş bırakıldı çünkü AISATURN branding'i kalıcı olmalı
  end
end

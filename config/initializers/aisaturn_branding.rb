# AISATURN Branding Initializer
# Bu initializer, Rails başlangıcında AISATURN branding config'lerini garanti altına alır
# Her restart sonrası Chatwoot logolarının geri gelmesini önler

Rails.application.config.after_initialize do
  # Sadece production veya development'ta çalıştır
  next unless Rails.env.production? || Rails.env.development?

  begin
    # AISATURN branding config'lerini zorla güncelle
    branding_configs = {
      'INSTALLATION_NAME' => 'AISATURN',
      'BRAND_NAME' => '',
      'BRAND_URL' => 'https://aisaturn.co',
      'WIDGET_BRAND_URL' => 'https://aisaturn.co',
      'LOGO' => '/brand-assets/logo.png',
      'LOGO_DARK' => '/brand-assets/logo_dark.png',
      'LOGO_THUMBNAIL' => '/brand-assets/logo.png'
    }

    branding_configs.each do |name, value|
      config = InstallationConfig.find_by(name: name)
      if config
        # Mevcut değer farklıysa güncelle
        if config.value != value
          config.update!(value: value, locked: true)
          Rails.logger.info "AISATURN Branding: Updated #{name} to #{value}"
        end
      else
        # Config yoksa oluştur
        InstallationConfig.create!(name: name, value: value, locked: true)
        Rails.logger.info "AISATURN Branding: Created #{name} with value #{value}"
      end
    end

    # Cache'i temizle
    GlobalConfig.clear_cache
    Rails.logger.info 'AISATURN Branding: Cache cleared'
  rescue StandardError => e
    # Hata durumunda logla ama uygulamayı durdurma
    Rails.logger.error "AISATURN Branding Initializer Error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end
end


class ConfigLoader
  DEFAULT_OPTIONS = {
    config_path: nil,
    reconcile_only_new: true
  }.freeze

  def process(options = {})
    options = DEFAULT_OPTIONS.merge(options)
    # function of the "reconcile_only_new" flag
    # if true,
    #   it leaves the existing config and feature flags as it is and
    #   creates the missing configs and feature flags with their default values
    # if false,
    #   then it overwrites existing config and feature flags with default values
    #   also creates the missing configs and feature flags with their default values
    @reconcile_only_new = options[:reconcile_only_new]

    # setting the config path
    @config_path = options[:config_path].presence
    @config_path ||= Rails.root.join('config')

    # general installation configs
    reconcile_general_config

    # default account based feature configs
    reconcile_feature_config
  end

  def general_configs
    @config_path ||= Rails.root.join('config')
    @general_configs ||= YAML.safe_load(File.read("#{@config_path}/installation_config.yml")).freeze
  end

  private

  def account_features
    @account_features ||= YAML.safe_load(File.read("#{@config_path}/features.yml")).freeze
  end

  def reconcile_general_config
    general_configs.each do |config|
      new_config = config.with_indifferent_access
      existing_config = InstallationConfig.find_by(name: new_config[:name])
      save_general_config(existing_config, new_config)
    end
  end

  def save_general_config(existing, latest)
    # Branding config'leri her zaman güncellensin (Chatwoot -> AISATURN dönüşümünü önlemek için)
    # AISATURN logoları: logo.png (açık tema - aisaturnkoyu.png), logo_dark.png (koyu tema - beyaz.png)
    branding_configs = ['INSTALLATION_NAME', 'BRAND_NAME', 'BRAND_URL', 'WIDGET_BRAND_URL', 'LOGO', 'LOGO_DARK', 'LOGO_THUMBNAIL']
    
    if existing
      if branding_configs.include?(latest[:name])
        # Branding config'leri her zaman güncelle (reconcile_only_new flag'ine bakmadan)
        # Bu sayede migration veya restart sonrası Chatwoot logoları geri gelmez
        # AISATURN değerlerini zorla uygula
        aisaturn_values = {
          'INSTALLATION_NAME' => 'AISATURN',
          'BRAND_NAME' => '',
          'BRAND_URL' => 'https://aisaturn.co',
          'WIDGET_BRAND_URL' => 'https://aisaturn.co',
          'LOGO' => '/brand-assets/logo.png',
          'LOGO_DARK' => '/brand-assets/logo_dark.png',
          'LOGO_THUMBNAIL' => '/brand-assets/logo.png'
        }
        
        # AISATURN değerini zorla kullan
        latest[:value] = aisaturn_values[latest[:name]] if aisaturn_values.key?(latest[:name])
        save_as_new_config(latest)
      elsif !@reconcile_only_new && compare_values(existing, latest)
        # Diğer config'ler için normal mantık
        save_as_new_config(latest)
      end
    else
      # Yeni config oluşturulurken de AISATURN değerlerini kullan
      if branding_configs.include?(latest[:name])
        aisaturn_values = {
          'INSTALLATION_NAME' => 'AISATURN',
          'BRAND_NAME' => '',
          'BRAND_URL' => 'https://aisaturn.co',
          'WIDGET_BRAND_URL' => 'https://aisaturn.co',
          'LOGO' => '/brand-assets/logo.png',
          'LOGO_DARK' => '/brand-assets/logo_dark.png',
          'LOGO_THUMBNAIL' => '/brand-assets/logo.png'
        }
        latest[:value] = aisaturn_values[latest[:name]] if aisaturn_values.key?(latest[:name])
      end
      save_as_new_config(latest)
    end
  end

  def compare_values(existing, latest)
    existing.value != latest[:value] ||
      (!latest[:locked].nil? && existing.locked != latest[:locked])
  end

  def save_as_new_config(latest)
    config = InstallationConfig.find_or_initialize_by(name: latest[:name])
    config.value = latest[:value]
    config.locked = latest[:locked]
    config.save!
  end

  def reconcile_feature_config
    config = InstallationConfig.find_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')

    if config
      return false if config.value.to_s == account_features.to_s

      compare_and_save_feature(config)
    else
      save_as_new_config({ name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS', value: account_features, locked: true })
    end
  end

  def compare_and_save_feature(config)
    features = if @reconcile_only_new
                 # leave the existing feature flag values as it is and add new feature flags with default values
                 (config.value + account_features).uniq { |h| h['name'] }
               else
                 # update the existing feature flag values with default values and add new feature flags with default values
                 (account_features + config.value).uniq { |h| h['name'] }
               end
    config.update({ name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS', value: features, locked: true })
  end
end

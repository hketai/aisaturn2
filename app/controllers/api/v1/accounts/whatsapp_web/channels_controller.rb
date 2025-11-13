class Api::V1::Accounts::WhatsappWeb::ChannelsController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_channel, only: [:show, :update, :destroy, :qr_code, :status, :start, :stop]

  def create
    @channel = Current.account.channel_whatsapp_webs.build(channel_params)
    @channel.save!
    render json: @channel
  end

  def show
    render json: @channel
  end

  def update
    @channel.update!(channel_params)
    render json: @channel
  end

  def destroy
    @channel.destroy!
    head :ok
  end

  def qr_code
    qr_data = WhatsappWeb::ClientService.new(channel: @channel).get_qr_code
    
    if qr_data.present? && qr_data[:qr_code].present?
      render json: {
        qr_code: qr_data[:qr_code],
        expires_at: qr_data[:expires_at] || @channel.qr_code_expires_at,
        token: @channel.qr_code_token
      }
    else
      render json: { error: 'QR code not available', message: 'QR code henüz oluşturulmadı. Lütfen birkaç saniye bekleyin.' }, status: :not_found
    end
  rescue StandardError => e
    Rails.logger.error "WhatsApp Web QR code error: #{e.class.name}: #{e.message}"
    error_message = if e.message.include?('Connection refused') || e.message.include?('ECONNREFUSED')
                      'WhatsApp Web Node.js servisi çalışmıyor.'
                    else
                      e.message
                    end
    render json: { error: error_message, message: error_message }, status: :unprocessable_entity
  end

  def status
    status_data = WhatsappWeb::ClientService.new(channel: @channel).get_client_status
    render json: status_data || { status: @channel.status, phone_number: @channel.phone_number }
  rescue StandardError => e
    Rails.logger.error "WhatsApp Web status error: #{e.class.name}: #{e.message}"
    # Return channel status even if Node.js service is unavailable
    render json: { 
      status: @channel.status, 
      phone_number: @channel.phone_number,
      error: e.message.include?('Connection refused') ? 'Node.js servisi çalışmıyor' : nil
    }
  end

  def start
    WhatsappWeb::ClientService.new(channel: @channel).start_client
    render json: { message: 'Client started', status: @channel.reload.status }
  rescue StandardError => e
    Rails.logger.error "WhatsApp Web start error: #{e.class.name}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n") if Rails.env.development?
    
    error_message = if e.message.include?('Connection refused') || e.message.include?('ECONNREFUSED')
                      'WhatsApp Web Node.js servisi çalışmıyor. Lütfen Node.js servisini başlatın.'
                    else
                      e.message
                    end
    
    render json: { error: error_message, message: error_message }, status: :unprocessable_entity
  end

  def stop
    WhatsappWeb::ClientService.new(channel: @channel).stop_client
    render json: { message: 'Client stopped' }
  end

  private

  def fetch_channel
    @channel = Current.account.channel_whatsapp_webs.find_by(id: params[:id])
    unless @channel
      Rails.logger.error "Channel not found: id=#{params[:id]}, account_id=#{Current.account.id}"
      render json: { error: 'Channel not found', message: 'Kanal bulunamadı' }, status: :not_found
    end
  end

  def channel_params
    params.require(:channel).permit(:phone_number, provider_config: {})
  end

  def check_authorization
    authorize :inbox, :create?
  end
end


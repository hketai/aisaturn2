class Sms::IncomingMessageService
  include ::FileTypeHelper

  pattr_initialize [:inbox!, :params!]

  RESOLVED_THRESHOLD = 24.hours   # Resolved için 24 saat
  UNRESOLVED_THRESHOLD = 7.days   # Open için 7 gün

  def perform
    set_contact
    set_conversation
    @message = @conversation.messages.create!(
      content: params[:text],
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      message_type: :incoming,
      sender: @contact,
      source_id: params[:id]
    )
    attach_files
    @message.save!
  end

  private

  def account
    @account ||= @inbox.account
  end

  def channel
    @channel ||= @inbox.channel
  end

  def phone_number
    params[:from]
  end

  def formatted_phone_number
    TelephoneNumber.parse(phone_number).international_number
  end

  def set_contact
    contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: params[:from],
      inbox: @inbox,
      contact_attributes: contact_attributes
    ).perform

    @contact_inbox = contact_inbox
    @contact = contact_inbox.contact
  end

  def conversation_params
    {
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      contact_id: @contact.id,
      contact_inbox_id: @contact_inbox.id
    }
  end

  def set_conversation
    @conversation = if @inbox.lock_to_single_conversation
                      # Kilitli ise her zaman son conversation
                      @contact_inbox.conversations.order(created_at: :desc).first
                    else
                      # Önce resolved olmayan conversation'ları kontrol et
                      unresolved = @contact_inbox.conversations
                                                   .where.not(status: :resolved)
                                                   .order(created_at: :desc)
                                                   .first

                      if unresolved
                        # Resolved olmayan conversation var
                        # Son aktiviteden 48 saat geçmişse yeni aç, değilse mevcut olanı kullan
                        if unresolved.last_activity_at < UNRESOLVED_THRESHOLD.ago
                          nil # Yeni conversation açılacak
                        else
                          unresolved
                        end
                      else
                        # Resolved olmayan conversation yok, resolved conversation'ları kontrol et
                        resolved = @contact_inbox.conversations
                                                  .resolved
                                                  .order(created_at: :desc)
                                                  .first

                        if resolved
                          # Son aktiviteden 24 saat geçmişse yeni aç, değilse mevcut olanı aç
                          if resolved.last_activity_at < RESOLVED_THRESHOLD.ago
                            nil # Yeni conversation açılacak
                          else
                            resolved.open! # Resolved'dan open'a çevir
                            resolved
                          end
                        else
                          nil # Hiç conversation yok, yeni açılacak
                        end
                      end
                    end

    return if @conversation

    # Yeni conversation aç
    @conversation = ::Conversation.create!(conversation_params)
  end

  def contact_attributes
    {
      name: formatted_phone_number,
      phone_number: phone_number
    }
  end

  def attach_files
    return if params[:media].blank?

    params[:media].each do |media_url|
      # we don't need to process this files since chatwoot doesn't support it
      next if media_url.end_with?('.smil', '.xml')

      attachment_file = Down.download(
        media_url,
        http_basic_authentication: [channel.provider_config['api_key'], channel.provider_config['api_secret']]
      )

      @message.attachments.new(
        account_id: @message.account_id,
        file_type: file_type(attachment_file.content_type),
        file: {
          io: attachment_file,
          filename: attachment_file.original_filename,
          content_type: attachment_file.content_type
        }
      )
    end
  end
end

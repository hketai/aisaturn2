class Twitter::TweetParserService < Twitter::WebhooksBaseService

  RESOLVED_THRESHOLD = 24.hours
  UNRESOLVED_THRESHOLD = 7.days
  pattr_initialize [:payload]

  def perform
    set_inbox

    return if !tweets_enabled? || message_already_exist? || user_has_blocked?

    create_message
  end

  private

  def message_type
    user['id'] == profile_id ? :outgoing : :incoming
  end

  def tweet_text
    tweet_data['truncated'] ? tweet_data['extended_tweet']['full_text'] : tweet_data['text']
  end

  def tweet_create_events_params
    payload['tweet_create_events']
  end

  def tweet_data
    tweet_create_events_params.first
  end

  def user
    tweet_data['user']
  end

  def tweet_id
    tweet_data['id'].to_s
  end

  def user_has_blocked?
    payload['user_has_blocked'] == true
  end

  def tweets_enabled?
    @inbox.channel.tweets_enabled?
  end

  def parent_tweet_id
    tweet_data['in_reply_to_status_id_str'].nil? ? tweet_data['id'].to_s : tweet_data['in_reply_to_status_id_str']
  end

  def conversation_params
    {
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      contact_id: @contact.id,
      contact_inbox_id: @contact_inbox.id,
      additional_attributes: {
        type: 'tweet',
        tweet_id: parent_tweet_id,
        tweet_source: tweet_data['source']
      }
    }
  end

  def set_conversation

    # Tweet ID'ye göre conversation'ları filtrele
    tweet_conversations = @contact_inbox.conversations.where("additional_attributes ->> 'tweet_id' = ?", parent_tweet_id)

    # Önce resolved olmayan conversation'ları kontrol et
    unresolved = tweet_conversations.where.not(status: :resolved).order(created_at: :desc).first

    if unresolved
      # Resolved olmayan conversation var
      # Son aktiviteden 48 saat geçmişse yeni aç, değilse mevcut olanı kullan
      if unresolved.last_activity_at < UNRESOLVED_THRESHOLD.ago
        @conversation = nil # Yeni conversation açılacak
      else
        @conversation = unresolved
        return
      end
    else
      # Resolved olmayan conversation yok, resolved conversation'ları kontrol et
      resolved = tweet_conversations.resolved.order(created_at: :desc).first

      if resolved
        # Son aktiviteden 24 saat geçmişse yeni aç, değilse mevcut olanı aç
        if resolved.last_activity_at < RESOLVED_THRESHOLD.ago
          @conversation = nil # Yeni conversation açılacak
        else
          resolved.open! # Resolved'dan open'a çevir
          @conversation = resolved
          return
        end
      end
    end

    # Tweet ID'ye göre conversation bulunamadı, parent tweet'in conversation'ını kontrol et
    tweet_message = @inbox.messages.find_by(source_id: parent_tweet_id)
    if tweet_message && tweet_message.conversation
      @conversation = tweet_message.conversation
      return
    end

    # Yeni conversation aç
    @conversation = ::Conversation.create!(conversation_params)
  end

  def message_already_exist?
    @inbox.messages.find_by(source_id: tweet_id)
  end

  def create_message
    find_or_create_contact(user)
    set_conversation
    @conversation.messages.create!(
      account_id: @inbox.account_id,
      sender: @contact,
      content: tweet_text,
      inbox_id: @inbox.id,
      message_type: message_type,
      source_id: tweet_id
    )
  end
end

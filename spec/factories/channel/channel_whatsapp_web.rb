FactoryBot.define do
  factory :channel_whatsapp_web, class: 'Channel::WhatsappWeb' do
    account
    sequence(:phone_number) { |n| "+198765432#{n}" }
    status { 'connected' }
    provider_config { { 'pending_inbox_name' => 'WhatsApp Web Inbox' } }

    after(:create) do |channel|
      create(:inbox, channel: channel, account: channel.account)
    end
  end
end

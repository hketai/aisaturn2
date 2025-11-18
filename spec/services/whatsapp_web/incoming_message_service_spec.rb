require 'rails_helper'

RSpec.describe WhatsappWeb::IncomingMessageService do
  describe '#perform' do
    let(:channel) { create(:channel_whatsapp_web) }
    let(:attachments) { [] }
    let(:message_data) do
      {
        id: 'wamid-123',
        from: '+1234567890@c.us',
        body: 'Hello there',
        type: 'text',
        contact_name: 'Ada',
        attachments: attachments
      }
    end

    subject(:process_message) { described_class.new(channel: channel, message_data: message_data).perform }

    context 'when attachments contain base64 data' do
      let(:file_path) { Rails.root.join('spec/fixtures/files/sample.pdf') }
      let(:base64_data) { Base64.strict_encode64(File.binread(file_path)) }
      let(:attachments) do
        [
          {
            data: base64_data,
            mimetype: 'application/pdf',
            filename: 'sample.pdf'
          }
        ]
      end

      it 'creates attachment from inline data' do
        expect { process_message }.to change(ActiveStorage::Attachment, :count).by(1)

        message = channel.inbox.messages.last
        expect(message.attachments.size).to eq(1)
        blob = message.attachments.first.file.blob
        expect(blob.filename.to_s).to eq('sample.pdf')
        expect(blob.content_type).to eq('application/pdf')
      end
    end
  end
end

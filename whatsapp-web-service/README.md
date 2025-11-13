# WhatsApp Web Service

Node.js service for managing WhatsApp Web clients using whatsapp-web.js.

## Setup

```bash
npm install
```

## Configuration

Create `.env` file:

```
PORT=3001
RAILS_API_URL=http://localhost:3000
```

## Run

```bash
npm start
# or for development
npm run dev
```

## API Endpoints

- `POST /api/channels/:channelId/start` - Start WhatsApp client
- `POST /api/channels/:channelId/stop` - Stop WhatsApp client
- `GET /api/channels/:channelId/qr` - Get QR code status
- `GET /api/channels/:channelId/status` - Get client status
- `POST /api/channels/:channelId/send` - Send message
- `GET /health` - Health check


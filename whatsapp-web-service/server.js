/**
 * WhatsApp Web Service
 * Node.js service that manages WhatsApp Web clients using whatsapp-web.js
 * 
 * Architecture:
 * - Each channel has its own WhatsApp client instance
 * - Hybrid Storage: Auth data from PostgreSQL, Cache from Object Storage
 * - Communicates with Rails app via HTTP API
 */

const { Client, LocalAuth, MessageMedia } = require('whatsapp-web.js');
const qrcode = require('qrcode-terminal');
const QRCode = require('qrcode');
const express = require('express');
const cors = require('cors');
const axios = require('axios');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 3001;
const RAILS_API_URL = process.env.RAILS_API_URL || 'http://localhost:3000';

// Store active clients
const clients = new Map();
// Store QR codes temporarily (channelId -> { qr_code, expires_at })
const qrCodes = new Map();

/**
 * Initialize WhatsApp client for a channel
 */
async function initializeClient(channelId, authData, cacheData) {
  try {
    // Create client with LocalAuth (uses authData if provided)
    const client = new Client({
      authStrategy: new LocalAuth({
        clientId: `channel_${channelId}`,
        dataPath: `./sessions/channel_${channelId}`
      }),
      puppeteer: {
        headless: true,
        args: [
          '--no-sandbox',
          '--disable-setuid-sandbox',
          '--disable-dev-shm-usage',
          '--disable-accelerated-2d-canvas',
          '--no-first-run',
          '--no-zygote',
          '--disable-gpu'
        ]
      }
    });

    // QR Code event
    client.on('qr', async (qr) => {
      console.log(`[Channel ${channelId}] QR Code generated`);
      
      // Convert QR code string to base64 image
      let qrCodeBase64;
      try {
        qrCodeBase64 = await QRCode.toDataURL(qr);
        // Remove data URL prefix to get just base64
        qrCodeBase64 = qrCodeBase64.replace(/^data:image\/png;base64,/, '');
      } catch (error) {
        console.error(`[Channel ${channelId}] Failed to convert QR code to image:`, error.message);
        // Fallback: use the raw QR string (it's already a base64-like string)
        qrCodeBase64 = qr;
      }
      
      // Store QR code temporarily (channelId is already a string from initializeClient)
      const expiresAt = new Date(Date.now() + 2 * 60 * 1000);
      qrCodes.set(String(channelId), {
        qr_code: qrCodeBase64,
        expires_at: expiresAt.toISOString()
      });
      
      // Print QR code to terminal (for debugging)
      qrcode.generate(qr, { small: true });
      
      // Send QR code to Rails app
      try {
        await axios.post(`${RAILS_API_URL}/webhooks/whatsapp_web`, {
          channel_id: channelId,
          event_type: 'qr',
          qr_data: {
            qr_code: qrCodeBase64,
            expires_at: expiresAt.toISOString()
          }
        });
      } catch (error) {
        console.error(`[Channel ${channelId}] Failed to send QR code:`, error.message);
      }
    });

    // Ready event
    client.on('ready', async () => {
      console.log(`[Channel ${channelId}] Client is ready!`);
      
      // Clear QR code as client is now connected
      qrCodes.delete(String(channelId));
      
      const info = client.info;
      const phoneNumber = info.wid.user;
      
      // Save auth data to Rails
      await saveAuthData(channelId, client);
      
      // Send ready event to Rails
      try {
        await axios.post(`${RAILS_API_URL}/webhooks/whatsapp_web`, {
          channel_id: channelId,
          event_type: 'ready',
          phone_number: phoneNumber
        });
      } catch (error) {
        console.error(`[Channel ${channelId}] Failed to send ready event:`, error.message);
      }
    });

    // Message event
    client.on('message', async (message) => {
      console.log(`[Channel ${channelId}] Message received from ${message.from}`);
      
      // Filter out unwanted messages:
      // 1. Group messages (@g.us suffix)
      // 2. Status messages (status updates)
      // 3. System/notification messages
      if (shouldIgnoreMessage(message)) {
        console.log(`[Channel ${channelId}] Ignoring message: group=${message.from?.includes('@g.us')}, status=${message.isStatus}, notification=${message.isNotification}`);
        return;
      }
      
      // Process message and send to Rails
      await processIncomingMessage(channelId, message);
    });

    // Message acknowledgment event (for sent messages)
    client.on('message_ack', async (message, ack) => {
      console.log(`[Channel ${channelId}] Message ACK received:`, message.id._serialized, 'ACK:', ack);
      
      // Map ACK types to statuses:
      // ACK_SERVER (1): Message delivered to server → 'delivered'
      // ACK_DEVICE (2): Message delivered to device → 'delivered'
      // ACK_READ (3): Message read → 'read'
      let status = null;
      if (ack === 1 || ack === 2) {
        status = 'delivered';
      } else if (ack === 3) {
        status = 'read';
      }
      
      if (status) {
        try {
          await axios.post(`${RAILS_API_URL}/webhooks/whatsapp_web`, {
            channel_id: channelId,
            event_type: 'message_ack',
            message_id: message.id._serialized,
            status: status
          });
        } catch (error) {
          console.error(`[Channel ${channelId}] Failed to send message ACK:`, error.message);
        }
      }
    });

    // Disconnected event
    client.on('disconnected', async (reason) => {
      console.log(`[Channel ${channelId}] Client disconnected:`, reason);
      
      // Send disconnected event to Rails
      try {
        await axios.post(`${RAILS_API_URL}/webhooks/whatsapp_web`, {
          channel_id: channelId,
          event_type: 'disconnected',
          reason: reason
        });
      } catch (error) {
        console.error(`[Channel ${channelId}] Failed to send disconnected event:`, error.message);
      }
      
      // Clean up client and remove from map
      client.destroy();
      clients.delete(String(channelId));
      qrCodes.delete(String(channelId)); // Clear QR code on disconnect
    });

    // Authentication failure
    client.on('auth_failure', async (msg) => {
      console.error(`[Channel ${channelId}] Authentication failure:`, msg);
      
      try {
        await axios.post(`${RAILS_API_URL}/webhooks/whatsapp_web`, {
          channel_id: channelId,
          event_type: 'auth_failure',
          message: msg
        });
      } catch (error) {
        console.error(`[Channel ${channelId}] Failed to send auth failure:`, error.message);
      }
      
      // Clean up client and remove from map
      client.destroy();
      clients.delete(String(channelId));
      qrCodes.delete(String(channelId)); // Clear QR code on auth failure
    });

    // Initialize client
    await client.initialize();
    clients.set(String(channelId), client);

    return { success: true, status: 'initializing' };
  } catch (error) {
    console.error(`[Channel ${channelId}] Initialization error:`, error.message);
    throw error;
  }
}

/**
 * Process incoming message and send to Rails
 */
/**
 * Check if a message should be ignored (not sent to Rails)
 * Filters out:
 * - Group messages (@g.us suffix)
 * - Status messages (status updates)
 * - System/notification messages
 */
function shouldIgnoreMessage(message) {
  // 1. Group messages have @g.us suffix in the 'from' field
  if (message.from && message.from.includes('@g.us')) {
    return true;
  }
  
  // 2. Status messages (WhatsApp status updates)
  if (message.isStatus === true || message.from === 'status@broadcast') {
    return true;
  }
  
  // 3. System/notification messages
  if (message.isNotification === true || message.type === 'notification') {
    return true;
  }
  
  // 4. Protocol/system messages (usually have no body and are not group messages)
  if (message.type === 'protocol' || message.type === 'system') {
    return true;
  }
  
  // 5. Empty messages that are not media (likely system messages)
  if (!message.body && !message.hasMedia && !message.isGroupMsg) {
    return true;
  }
  
  return false;
}

async function processIncomingMessage(channelId, message) {
  try {
    const messageData = {
      id: message.id._serialized,
      from: message.from,
      body: message.body,
      type: message.type,
      timestamp: message.timestamp,
      contact_name: (await message.getContact()).name || null,
      caption: message.caption || null
    };

    // Handle media attachments
    if (message.hasMedia) {
      const media = await message.downloadMedia();
      messageData.attachments = [{
        mimetype: media.mimetype,
        data: media.data,
        filename: media.filename || null
      }];
    }

    // Send to Rails webhook
    await axios.post(`${RAILS_API_URL}/webhooks/whatsapp_web`, {
      channel_id: channelId,
      event_type: 'message',
      message_data: messageData
    });
  } catch (error) {
    console.error(`[Channel ${channelId}] Failed to process message:`, error.message);
  }
}

/**
 * Save auth data to Rails (via webhook)
 */
async function saveAuthData(channelId, client) {
  try {
    // Get auth data from client session
    // This will be handled by LocalAuth, but we can also send updates to Rails
    const info = client.info;
    
    await axios.post(`${RAILS_API_URL}/webhooks/whatsapp_web`, {
      channel_id: channelId,
      event_type: 'auth_update',
      auth_data: {
        wid: info.wid,
        pushname: info.pushname
      }
    });
  } catch (error) {
    console.error(`[Channel ${channelId}] Failed to save auth data:`, error.message);
  }
}

/**
 * Send message via WhatsApp
 */
async function sendMessage(channelId, phoneNumber, messageContent, attachments = []) {
  const client = clients.get(String(channelId));
  if (!client) {
    throw new Error('Client not initialized');
  }

  try {
    let messageId;

    if (attachments.length > 0) {
      // Send with media
      const attachment = attachments[0];
      const media = MessageMedia.fromFilePath(attachment.url);
      if (attachment.caption) {
        media.caption = attachment.caption;
      }
      const message = await client.sendMessage(phoneNumber, media);
      messageId = message.id._serialized;
    } else {
      // Send text message
      const message = await client.sendMessage(phoneNumber, messageContent);
      messageId = message.id._serialized;
    }

    return { success: true, message_id: messageId };
  } catch (error) {
    console.error(`[Channel ${channelId}] Send message error:`, error.message);
    return { success: false, error: error.message };
  }
}

// API Routes

/**
 * Start client for a channel
 */
app.post('/client/start', async (req, res) => {
  const { channel_id, auth_data, cache_data } = req.body;

  try {
    if (!channel_id) {
      return res.status(400).json({ error: 'channel_id is required' });
    }

    // Convert channel_id to string for consistent Map key usage
    const channelIdStr = String(channel_id);

    if (clients.has(channelIdStr)) {
      return res.json({ success: true, status: 'already_running', message: 'Client already running' });
    }

    await initializeClient(channelIdStr, auth_data, cache_data);
    res.json({ success: true, status: 'connecting', message: 'Client started' });
  } catch (error) {
    console.error(`[Channel ${channel_id}] Start error:`, error.message);
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * Stop client for a channel
 */
app.post('/client/stop', async (req, res) => {
  const { channel_id } = req.body;

  try {
    if (!channel_id) {
      return res.status(400).json({ error: 'channel_id is required' });
    }

    // Convert channel_id to string for consistent Map key usage
    const channelIdStr = String(channel_id);

    const client = clients.get(channelIdStr);
    if (client) {
      await client.destroy();
      clients.delete(channelIdStr);
      qrCodes.delete(channelIdStr); // Clear QR code too
      res.json({ success: true, message: 'Client stopped' });
    } else {
      res.json({ success: true, message: 'Client not running' });
    }
  } catch (error) {
    console.error(`[Channel ${channel_id}] Stop error:`, error.message);
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * Get QR code for a channel
 */
app.get('/client/:channelId/qr', async (req, res) => {
  const { channelId } = req.params;

  try {
    // Convert channelId to string for consistent Map key usage
    const channelIdStr = String(channelId);
    
    const qrData = qrCodes.get(channelIdStr);
    if (!qrData) {
      // Check if client exists but QR not generated yet
      const client = clients.get(channelIdStr);
      if (!client) {
        return res.status(404).json({ error: 'Client not initialized' });
      }
      return res.status(404).json({ error: 'QR code not available yet' });
    }

    // Check if QR code expired
    if (new Date(qrData.expires_at) < new Date()) {
      qrCodes.delete(channelIdStr);
      return res.status(404).json({ error: 'QR code expired' });
    }

    res.json({
      qr_code: qrData.qr_code,
      expires_at: qrData.expires_at
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

/**
 * Get status of a channel
 */
app.get('/client/:channelId/status', async (req, res) => {
  const { channelId } = req.params;

  try {
    // Convert channelId to string for consistent Map key usage
    const channelIdStr = String(channelId);
    
    const client = clients.get(channelIdStr);
    if (!client) {
      return res.json({ success: true, status: 'disconnected', phone_number: null });
    }

    const state = await client.getState();
    const info = client.info;
    const phoneNumber = info?.wid?.user || null;
    
    res.json({ 
      success: true,
      status: state === 'CONNECTED' ? 'connected' : 'connecting',
      phone_number: phoneNumber,
      state: state
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * Send message
 */
app.post('/client/:channelId/send-message', async (req, res) => {
  const { channelId } = req.params;
  const { to, message, attachments } = req.body;

  try {
    // Convert channelId to string for consistent Map key usage
    const channelIdStr = String(channelId);
    const result = await sendMessage(channelIdStr, to, message, attachments);
    res.json(result);
  } catch (error) {
    console.error(`[Channel ${channelId}] Send error:`, error.message);
    res.status(500).json({ success: false, error: error.message });
  }
});

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', active_clients: clients.size });
});

// Start server
app.listen(PORT, () => {
  console.log(`WhatsApp Web Service running on port ${PORT}`);
});


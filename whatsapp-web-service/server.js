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
// Store processed message IDs per channel to prevent duplicates
const processedMessageIds = new Map(); // channelId -> Set of message IDs

/**
 * Clean up stale session locks
 */
function cleanupSessionLocks(channelIdStr) {
  const fs = require('fs');
  const path = require('path');
  const sessionPath = path.join('./sessions', `channel_${channelIdStr}`);
  const lockPath = path.join(sessionPath, 'session-channel_' + channelIdStr, 'SingletonLock');
  
  try {
    if (fs.existsSync(lockPath)) {
      fs.unlinkSync(lockPath);
      console.log(`[Channel ${channelIdStr}] Cleaned up stale SingletonLock`);
    }
  } catch (error) {
    console.log(`[Channel ${channelIdStr}] Could not clean up lock (may not exist): ${error.message}`);
  }
}

/**
 * Initialize WhatsApp client for a channel
 */
async function initializeClient(channelId, authData, cacheData) {
  try {
    // Convert channelId to string for consistent Map key usage
    const channelIdStr = String(channelId);
    
    // Clean up any stale session locks before starting
    cleanupSessionLocks(channelIdStr);
    
    // Create client with LocalAuth (uses authData if provided)
    const client = new Client({
      authStrategy: new LocalAuth({
        clientId: `channel_${channelIdStr}`,
        dataPath: `./sessions/channel_${channelIdStr}`
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
      console.log(`[Channel ${channelIdStr}] QR Code generated`);
      
      // Convert QR code string to base64 image
      let qrCodeBase64;
      try {
        qrCodeBase64 = await QRCode.toDataURL(qr);
        // Remove data URL prefix to get just base64
        qrCodeBase64 = qrCodeBase64.replace(/^data:image\/png;base64,/, '');
      } catch (error) {
        console.error(`[Channel ${channelIdStr}] Failed to convert QR code to image:`, error.message);
        // Fallback: use the raw QR string (it's already a base64-like string)
        qrCodeBase64 = qr;
      }
      
      // Store QR code temporarily
      const expiresAt = new Date(Date.now() + 2 * 60 * 1000);
      qrCodes.set(channelIdStr, {
        qr_code: qrCodeBase64,
        expires_at: expiresAt.toISOString()
      });
      
      // Print QR code to terminal (for debugging)
      qrcode.generate(qr, { small: true });
      
      // Send QR code to Rails app
      try {
        await axios.post(`${RAILS_API_URL}/webhooks/whatsapp_web`, {
          channel_id: channelIdStr,
          event_type: 'qr',
          qr_data: {
            qr_code: qrCodeBase64,
            expires_at: expiresAt.toISOString()
          }
        });
      } catch (error) {
        console.error(`[Channel ${channelIdStr}] Failed to send QR code:`, error.message);
      }
    });

    // Ready event
    client.on('ready', async () => {
      console.log(`[Channel ${channelIdStr}] Client is ready!`);
      
      // Clear QR code as client is now connected
      qrCodes.delete(channelIdStr);
      
      const info = client.info;
      const phoneNumber = info.wid.user;
      
      // Save auth data to Rails
      await saveAuthData(channelIdStr, client);
      
      // Send ready event to Rails
      try {
        await axios.post(`${RAILS_API_URL}/webhooks/whatsapp_web`, {
          channel_id: channelIdStr,
          event_type: 'ready',
          phone_number: phoneNumber
        });
      } catch (error) {
        console.error(`[Channel ${channelIdStr}] Failed to send ready event:`, error.message);
      }
    });

    // Initialize processed message IDs Set for this channel
    if (!processedMessageIds.has(channelIdStr)) {
      processedMessageIds.set(channelIdStr, new Set());
    }
    const channelProcessedIds = processedMessageIds.get(channelIdStr);
    
    // Message event - catches all messages (including from phone)
    client.on('message', async (message) => {
      const messageId = message.id._serialized;
      const messageFrom = message.from || 'unknown';
      const messageBody = message.body?.substring(0, 50) || '(no body)';
      
      console.log(`[Channel ${channelIdStr}] ===== MESSAGE EVENT =====`);
      console.log(`[Channel ${channelIdStr}] Message ID: ${messageId}`);
      console.log(`[Channel ${channelIdStr}] From: ${messageFrom}`);
      console.log(`[Channel ${channelIdStr}] FromMe: ${message.fromMe}`);
      console.log(`[Channel ${channelIdStr}] Type: ${message.type}`);
      console.log(`[Channel ${channelIdStr}] Body: ${messageBody}`);
      console.log(`[Channel ${channelIdStr}] HasMedia: ${message.hasMedia}`);
      console.log(`[Channel ${channelIdStr}] IsStatus: ${message.isStatus}`);
      console.log(`[Channel ${channelIdStr}] IsNotification: ${message.isNotification}`);
      
      // Skip if already processed (prevent duplicates from multiple events)
      if (channelProcessedIds.has(messageId)) {
        console.log(`[Channel ${channelIdStr}] ⚠️ Message ${messageId} already processed, skipping`);
        return;
      }
      
      // Filter out unwanted messages:
      // 1. Group messages (@g.us suffix)
      // 2. Status messages (status updates)
      // 3. System/notification messages
      if (shouldIgnoreMessage(message)) {
        console.log(`[Channel ${channelIdStr}] ⚠️ Ignoring message (filtered): group=${messageFrom?.includes('@g.us')}, status=${message.isStatus}, notification=${message.isNotification}`);
        return;
      }
      
      // NOTE: We do NOT filter by fromMe here because:
      // 1. Phone messages from our number can have fromMe=true
      // 2. Panel messages will be filtered by duplicate check in Rails (source_id matching)
      // 3. We want to capture ALL messages and let Rails decide what to process
      
      console.log(`[Channel ${channelIdStr}] ✅ Processing message: ${messageId} (fromMe=${message.fromMe})`);
      
      // Mark as processed
      channelProcessedIds.add(messageId);
      
      // Process message and send to Rails
      await processIncomingMessage(channelIdStr, message);
    });

    // message_create event - catches new messages in real-time (better for phone messages)
    // This event fires when a NEW message is created (including from phone)
    client.on('message_create', async (message) => {
      const messageId = message.id._serialized;
      const messageFrom = message.from || 'unknown';
      
      console.log(`\n[Channel ${channelIdStr}] ========================================`);
      console.log(`[Channel ${channelIdStr}] ===== MESSAGE_CREATE EVENT FIRED =====`);
      console.log(`[Channel ${channelIdStr}] Message ID: ${messageId}`);
      console.log(`[Channel ${channelIdStr}] From: ${messageFrom}`);
      console.log(`[Channel ${channelIdStr}] FromMe: ${message.fromMe}`);
      console.log(`[Channel ${channelIdStr}] Type: ${message.type}`);
      console.log(`[Channel ${channelIdStr}] Body: ${message.body?.substring(0, 50) || '(no body)'}`);
      console.log(`[Channel ${channelIdStr}] ========================================\n`);
      
      // Skip if already processed
      if (channelProcessedIds.has(messageId)) {
        console.log(`[Channel ${channelIdStr}] ⚠️ Message_create: ${messageId} already processed, skipping`);
        return;
      }
      
      // Filter out unwanted messages
      if (shouldIgnoreMessage(message)) {
        console.log(`[Channel ${channelIdStr}] ⚠️ Message_create: Ignoring message (filtered)`);
        return;
      }
      
      // CRITICAL: We do NOT filter by fromMe here - duplicate check in Rails will handle panel messages
      
      console.log(`[Channel ${channelIdStr}] ✅ ACCEPTED: Message_create: Processing message: ${messageId} (fromMe=${message.fromMe}, from=${messageFrom})`);
      
      // Mark as processed
      channelProcessedIds.add(messageId);
      
      // Process message and send to Rails
      await processIncomingMessage(channelIdStr, message);
    });

    // Message acknowledgment event (for sent messages)
    client.on('message_ack', async (message, ack) => {
      console.log(`[Channel ${channelIdStr}] Message ACK received:`, message.id._serialized, 'ACK:', ack);
      
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
            channel_id: channelIdStr,
            event_type: 'message_ack',
            message_id: message.id._serialized,
            status: status
          });
        } catch (error) {
          console.error(`[Channel ${channelIdStr}] Failed to send message ACK:`, error.message);
        }
      }
    });

    // Disconnected event
    client.on('disconnected', async (reason) => {
      console.log(`[Channel ${channelIdStr}] Client disconnected:`, reason);
      
      // Send disconnected event to Rails
      try {
        await axios.post(`${RAILS_API_URL}/webhooks/whatsapp_web`, {
          channel_id: channelIdStr,
          event_type: 'disconnected',
          reason: reason
        });
      } catch (error) {
        console.error(`[Channel ${channelIdStr}] Failed to send disconnected event:`, error.message);
      }
      
      // Clean up client and remove from map
      client.destroy();
      clients.delete(channelIdStr);
      qrCodes.delete(channelIdStr); // Clear QR code on disconnect
      processedMessageIds.delete(channelIdStr); // Clear processed message IDs
    });

    // Authentication failure
    client.on('auth_failure', async (msg) => {
      console.error(`[Channel ${channelIdStr}] Authentication failure:`, msg);
      
      try {
        await axios.post(`${RAILS_API_URL}/webhooks/whatsapp_web`, {
          channel_id: channelIdStr,
          event_type: 'auth_failure',
          message: msg
        });
      } catch (error) {
        console.error(`[Channel ${channelIdStr}] Failed to send auth failure:`, error.message);
      }
      
      // Clean up client and remove from map
      client.destroy();
      clients.delete(channelIdStr);
      qrCodes.delete(channelIdStr); // Clear QR code on auth failure
      processedMessageIds.delete(channelIdStr); // Clear processed message IDs
    });

    // Initialize client
    await client.initialize();
    clients.set(channelIdStr, client);

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
  const from = message.from || '';
  
  // 1. Group messages have @g.us suffix in the 'from' field
  if (from.includes('@g.us')) {
    console.log(`[FILTER] Ignoring group message: ${from}`);
    return true;
  }
  
  // 2. Status messages (WhatsApp status updates)
  if (message.isStatus === true || from === 'status@broadcast') {
    console.log(`[FILTER] Ignoring status message: isStatus=${message.isStatus}, from=${from}`);
    return true;
  }
  
  // 3. System/notification messages
  if (message.isNotification === true || message.type === 'notification') {
    console.log(`[FILTER] Ignoring notification: isNotification=${message.isNotification}, type=${message.type}`);
    return true;
  }
  
  // 4. Protocol/system messages (usually have no body and are not group messages)
  if (message.type === 'protocol' || message.type === 'system') {
    console.log(`[FILTER] Ignoring protocol/system message: type=${message.type}`);
    return true;
  }
  
  // 5. Empty messages that are not media (likely system messages)
  // BUT: Allow media messages even if body is empty
  if (!message.body && !message.hasMedia && !message.isGroupMsg) {
    console.log(`[FILTER] Ignoring empty message: body=${message.body}, hasMedia=${message.hasMedia}`);
    return true;
  }
  
  // 6. Messages from broadcast lists (status@broadcast)
  if (from === 'status@broadcast') {
    console.log(`[FILTER] Ignoring broadcast message: ${from}`);
    return true;
  }
  
  console.log(`[FILTER] ✅ Message passed all filters: from=${from}, type=${message.type}, hasBody=${!!message.body}, fromMe=${message.fromMe}`);
  return false;
}

async function processIncomingMessage(channelId, message) {
  try {
    console.log(`[Channel ${channelId}] 🔄 Processing incoming message: ${message.id._serialized}`);
    
    // Get contact info with error handling
    let contactName = null;
    try {
      const contact = await message.getContact();
      contactName = contact.name || contact.pushname || null;
      console.log(`[Channel ${channelId}] Contact info: name=${contactName}, pushname=${contact.pushname}`);
    } catch (error) {
      console.error(`[Channel ${channelId}] ⚠️ Failed to get contact info:`, error.message);
    }

    const messageData = {
      id: message.id._serialized,
      from: message.from,
      to: message.to, // Needed to map outgoing phone messages back to the customer
      body: message.body,
      type: message.type,
      timestamp: message.timestamp,
      contact_name: contactName,
      caption: message.caption || null,
      fromMe: message.fromMe || false // Include fromMe flag for Rails processing
    };
    
    console.log(`[Channel ${channelId}] Message data prepared:`, {
      id: messageData.id,
      from: messageData.from,
      type: messageData.type,
      hasBody: !!messageData.body,
      fromMe: messageData.fromMe
    });

    // Handle media attachments with error handling
    if (message.hasMedia) {
      try {
        const media = await message.downloadMedia();
        messageData.attachments = [{
          mimetype: media.mimetype,
          data: media.data,
          filename: media.filename || null
        }];
      } catch (error) {
        console.error(`[Channel ${channelId}] Failed to download media:`, error.message);
        // Continue without media attachment
      }
    }

    // Send to Rails webhook with retry logic
    let retries = 3;
    let lastError = null;
    
    console.log(`[Channel ${channelId}] 📤 Sending message to Rails: ${RAILS_API_URL}/webhooks/whatsapp_web`);
    console.log(`[Channel ${channelId}] Message payload:`, JSON.stringify({
      channel_id: channelId,
      event_type: 'message',
      message_data: {
        id: messageData.id,
        from: messageData.from,
        fromMe: messageData.fromMe,
        type: messageData.type,
        hasBody: !!messageData.body,
        bodyLength: messageData.body?.length || 0
      }
    }, null, 2));
    
    while (retries > 0) {
      try {
        const response = await axios.post(`${RAILS_API_URL}/webhooks/whatsapp_web`, {
          channel_id: channelId,
          event_type: 'message',
          message_data: messageData
        }, {
          timeout: 10000 // 10 second timeout
        });
        console.log(`[Channel ${channelId}] ✅ Message ${messageData.id} sent to Rails successfully`);
        console.log(`[Channel ${channelId}] Rails response status: ${response.status}`);
        return; // Success, exit function
      } catch (error) {
        lastError = error;
        retries--;
        console.error(`[Channel ${channelId}] ❌ Failed to send message (${retries} retries left):`, error.message);
        if (error.response) {
          console.error(`[Channel ${channelId}] Rails response status: ${error.response.status}`);
          console.error(`[Channel ${channelId}] Rails response data:`, error.response.data);
        }
        if (retries > 0) {
          console.log(`[Channel ${channelId}] Retrying message send in 1 second...`);
          await new Promise(resolve => setTimeout(resolve, 1000)); // Wait 1 second before retry
        }
      }
    }
    
    // If all retries failed, log error
    console.error(`[Channel ${channelId}] ❌ Failed to send message to Rails after 3 retries:`, lastError.message);
    console.error(`[Channel ${channelId}] Last error details:`, lastError.response?.data || lastError.message);
  } catch (error) {
    console.error(`[Channel ${channelId}] ❌ Failed to process message:`, error.message);
    console.error(`[Channel ${channelId}] Error stack:`, error.stack);
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

    // If client already exists, stop it first to avoid conflicts
    if (clients.has(channelIdStr)) {
      try {
        const existingClient = clients.get(channelIdStr);
        await existingClient.destroy();
        clients.delete(channelIdStr);
        qrCodes.delete(channelIdStr);
        processedMessageIds.delete(channelIdStr);
        console.log(`[Channel ${channelIdStr}] Stopped existing client before restart`);
      } catch (error) {
        console.error(`[Channel ${channelIdStr}] Error stopping existing client:`, error.message);
      }
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
      processedMessageIds.delete(channelIdStr); // Clear processed message IDs
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


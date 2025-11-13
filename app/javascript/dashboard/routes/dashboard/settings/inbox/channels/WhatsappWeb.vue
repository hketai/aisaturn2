<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import PageHeader from '../../SettingsSubPageHeader.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import whatsappWebChannelAPI from 'dashboard/api/whatsappWeb/channel';
import inboxesAPI from 'dashboard/api/inboxes';

const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const accountId = computed(() => route.params.accountId);
const inboxId = computed(() => route.query.inbox_id);

const inboxName = ref('');
const isCreating = ref(false);
const channel = ref(null);
const qrCode = ref(null);
const status = ref('disconnected');
const qrCodeExpiresAt = ref(null);
const qrCodePollingInterval = ref(null);
const pendingInboxName = ref('');

const isConnected = computed(() => status.value === 'connected');
const isConnecting = computed(() => status.value === 'connecting');
// Show QR code if we have a channel and status is not connected
// Keep showing QR code even if status changes, as long as it's not connected
const showQrCode = computed(() => channel.value && !isConnected.value);

const startPollingQrCode = async channelId => {
  // Clear any existing interval
  if (qrCodePollingInterval.value) {
    clearInterval(qrCodePollingInterval.value);
  }

  // Ensure channelId is a string
  const channelIdStr = String(channelId);

  // Try to fetch QR code immediately (don't wait for first interval)
  try {
    const response = await whatsappWebChannelAPI.getQrCode({
      accountId: accountId.value,
      channelId: channelIdStr,
    });

    // Axios response format: {data: {qr_code: ..., expires_at: ...}}
    const qrData = response.data || response;

    if (qrData?.qr_code) {
      qrCode.value = qrData.qr_code;
      qrCodeExpiresAt.value = qrData.expires_at;
      status.value = 'connecting';
    }
  } catch (qrError) {
    // QR code not available yet, continue polling
  }

  // Poll for QR code every 2 seconds
  qrCodePollingInterval.value = setInterval(async () => {
    try {
      // First, check status
      const statusResponse = await whatsappWebChannelAPI.getStatus({
        accountId: accountId.value,
        channelId: channelIdStr,
      });

      // Axios response format: {data: {status: ...}} or direct {status: ...}
      const statusData = statusResponse.data || statusResponse;

      if (statusData?.status) {
        // Only update status if it's not already connected (to avoid clearing QR code prematurely)
        if (statusData.status === 'connected') {
          clearInterval(qrCodePollingInterval.value);
          qrCodePollingInterval.value = null;
          qrCode.value = null;
          status.value = 'connected';

          // Show success message
          useAlert(t('INBOX_MGMT.ADD.WHATSAPP_WEB.CONNECTED_SUCCESS'));

          // Inbox should be created by webhook, check if it exists and redirect to agents page
          // Retry mechanism: try up to 10 times with 500ms intervals (faster retry)
          let retryCount = 0;
          const maxRetries = 10;

          const checkInboxAndRedirect = async () => {
            try {
              // Fetch channel to get inbox ID
              const channelResponse = await whatsappWebChannelAPI.show({
                accountId: accountId.value,
                channelId: channelIdStr,
              });

              const channelData = channelResponse.data || channelResponse;
              const fetchedInboxId = channelData.inbox_id;

              if (fetchedInboxId) {
                // Redirect to agents page (step 3) immediately
                router.replace({
                  name: 'settings_inboxes_add_agents',
                  params: {
                    accountId: accountId.value,
                    inbox_id: fetchedInboxId,
                  },
                });
                // Exit retry loop
              } else {
                // Retry if inbox not found yet
                retryCount += 1;
                if (retryCount < maxRetries) {
                  setTimeout(checkInboxAndRedirect, 500); // Faster retry (500ms instead of 1000ms)
                } else {
                  // Fallback: reload page if inbox still not found after retries
                  window.location.reload();
                }
              }
            } catch (error) {
              // Retry on error
              retryCount += 1;
              if (retryCount < maxRetries) {
                setTimeout(checkInboxAndRedirect, 500); // Faster retry
              } else {
                // Fallback: reload page on error after retries
                window.location.reload();
              }
            }
          };

          // Start checking immediately (no delay)
          checkInboxAndRedirect();
          return;
        }
        if (statusData.status !== 'connected') {
          // Update status but don't clear QR code if status is connecting/disconnected
          status.value = statusData.status;
        }
      }

      // Only fetch QR code if not connected and status is connecting or disconnected
      if (status.value === 'connecting' || status.value === 'disconnected') {
        // Check if current QR code is expired
        const isExpired =
          qrCodeExpiresAt.value && new Date(qrCodeExpiresAt.value) < new Date();

        // Fetch new QR code if we don't have one or if current one is expired
        if (!qrCode.value || isExpired) {
          try {
            const response = await whatsappWebChannelAPI.getQrCode({
              accountId: accountId.value,
              channelId: channelIdStr,
            });

            // Axios response format: {data: {qr_code: ..., expires_at: ...}}
            const qrData = response.data || response;

            if (qrData?.qr_code) {
              qrCode.value = qrData.qr_code;
              qrCodeExpiresAt.value = qrData.expires_at;
              status.value = 'connecting';
            }
          } catch (qrError) {
            // QR code not available yet, continue polling
          }
        }
      }
    } catch (error) {
      // Continue polling even on error
    }
  }, 2000);
};

const loadChannel = async () => {
  try {
    // Load inbox to get channel info
    const inbox = await inboxesAPI.show({
      accountId: accountId.value,
      inboxId: inboxId.value,
    });
    if (inbox.channel_type === 'Channel::WhatsappWeb') {
      channel.value = inbox.channel;
      status.value = inbox.channel.status;
      await startPollingQrCode(String(inbox.channel.id));
    }
  } catch (error) {
    // Failed to load channel - silently fail
  }
};

const createChannel = async () => {
  if (!inboxName.value.trim()) {
    useAlert(t('INBOX_MGMT.ADD.WHATSAPP_WEB.NAME_REQUIRED'));
    return;
  }

  isCreating.value = true;

  try {
    // Create inbox with channel using inboxes API (like other channels)
    // Note: accountId is not needed as inboxesAPI is accountScoped
    const response = await inboxesAPI.create({
      inbox: {
        name: inboxName.value,
        channel: {
          type: 'whatsapp_web',
          phone_number: null, // Will be set after QR scan
        },
      },
    });

    // Response format for WhatsApp Web: { channel: {...}, inbox: null, requires_qr_scan: true }
    // or normal: { data: { payload: { id, name, channel: {...} } } }
    const responseData = response.data?.payload || response.data;

    // Check if this is WhatsApp Web with requires_qr_scan
    let channelId;
    if (responseData.requires_qr_scan && responseData.channel) {
      // WhatsApp Web: Only channel created, inbox will be created after QR scan
      const channelData = responseData.channel;
      channel.value = channelData;
      channelId = channelData.id;

      if (!channelId) {
        throw new Error('Channel ID not found in response');
      }

      // Store inbox name for later
      pendingInboxName.value = inboxName.value;
    } else {
      // Normal flow: Both channel and inbox created
      const inbox = responseData;
      channelId = inbox.channel?.id || inbox.channel_id;

      if (!channelId) {
        throw new Error('Channel ID not found in response');
      }

      channel.value = inbox.channel || { id: channelId };
    }

    // Wait a bit for transaction to commit before starting client
    await new Promise(resolve => {
      setTimeout(resolve, 500);
    });

    // Start client immediately to generate QR code
    try {
      await whatsappWebChannelAPI.start({
        accountId: accountId.value,
        channelId: channelId,
      });
      status.value = 'connecting';
    } catch (error) {
      const errorMessage =
        error?.response?.data?.error ||
        error?.response?.data?.message ||
        error?.message;

      // If channel not found, wait a bit more and retry
      if (
        error?.response?.status === 404 ||
        errorMessage?.includes('not found')
      ) {
        await new Promise(resolve => {
          setTimeout(resolve, 1000);
        });
        try {
          await whatsappWebChannelAPI.start({
            accountId: accountId.value,
            channelId: channelId,
          });
          status.value = 'connecting';
        } catch (retryError) {
          useAlert(
            errorMessage ||
              'WhatsApp Web Node.js servisi çalışmıyor. Lütfen servisi başlatın.'
          );
          status.value = 'disconnected';
        }
      } else {
        useAlert(
          errorMessage ||
            'WhatsApp Web Node.js servisi çalışmıyor. Lütfen servisi başlatın.'
        );
        status.value = 'disconnected';
      }
    }

    // Start polling for QR code immediately
    // Convert channelId to string for consistency
    startPollingQrCode(String(channelId));

    useAlert(t('INBOX_MGMT.ADD.WHATSAPP_WEB.CREATE_SUCCESS'));

    // Don't redirect - stay on this page to show QR code
    // User will see QR code and connection status on this page
  } catch (error) {
    const errorMessage =
      error?.response?.data?.error ||
      error?.response?.data?.message ||
      error?.message ||
      t('INBOX_MGMT.ADD.WHATSAPP_WEB.CREATE_ERROR');
    useAlert(errorMessage);
  } finally {
    isCreating.value = false;
  }
};

const regenerateQrCode = async () => {
  if (!channel.value) return;

  try {
    // Clear current QR code immediately to show loading state
    qrCode.value = null;
    qrCodeExpiresAt.value = null;

    // First stop the client if running
    try {
      await whatsappWebChannelAPI.stop({
        accountId: accountId.value,
        channelId: String(channel.value.id),
      });
    } catch (stopError) {
      // Stop client error - ignored
    }

    // Wait a bit before starting again
    await new Promise(resolve => {
      setTimeout(resolve, 1000);
    });

    // Start client again to generate new QR code
    await whatsappWebChannelAPI.start({
      accountId: accountId.value,
      channelId: String(channel.value.id),
    });
    status.value = 'connecting';

    // Restart polling to fetch new QR code
    if (qrCodePollingInterval.value) {
      clearInterval(qrCodePollingInterval.value);
      qrCodePollingInterval.value = null;
    }
    await startPollingQrCode(String(channel.value.id));

    useAlert(
      t('INBOX_MGMT.ADD.WHATSAPP_WEB.QR_CODE.REGENERATE') ||
        'QR kodu yeniden oluşturuluyor...'
    );
  } catch (error) {
    const errorMessage =
      error?.response?.data?.error ||
      error?.response?.data?.message ||
      error?.message;
    useAlert(errorMessage || t('INBOX_MGMT.ADD.WHATSAPP_WEB.REGENERATE_ERROR'));
  }
};

onMounted(async () => {
  if (inboxId.value) {
    await loadChannel();
  }
});

onUnmounted(() => {
  if (qrCodePollingInterval.value) {
    clearInterval(qrCodePollingInterval.value);
  }
});
</script>

<template>
  <div class="h-full w-full p-6 col-span-6">
    <PageHeader
      :header-title="$t('INBOX_MGMT.ADD.WHATSAPP_WEB.TITLE')"
      :header-content="$t('INBOX_MGMT.ADD.WHATSAPP_WEB.DESC')"
    />

    <div v-if="!channel" class="mt-6">
      <form @submit.prevent="createChannel">
        <div class="w-full mb-4">
          <Input
            v-model="inboxName"
            :label="$t('INBOX_MGMT.ADD.WHATSAPP_WEB.INBOX_NAME.LABEL')"
            :placeholder="
              $t('INBOX_MGMT.ADD.WHATSAPP_WEB.INBOX_NAME.PLACEHOLDER')
            "
            required
          />
        </div>

        <div class="w-full text-right">
          <Button
            type="submit"
            :is-loading="isCreating"
            :disabled="isCreating"
            :label="$t('INBOX_MGMT.ADD.WHATSAPP_WEB.CREATE_BUTTON')"
          />
        </div>
      </form>
    </div>

    <div v-else class="mt-6">
      <!-- Status Display -->
      <div
        class="mb-6 p-4 rounded-lg border"
        :class="{
          'bg-green-50 dark:bg-green-900/20 border-green-200 dark:border-green-800':
            isConnected,
          'bg-yellow-50 dark:bg-yellow-900/20 border-yellow-200 dark:border-yellow-800':
            isConnecting,
          'bg-gray-50 dark:bg-gray-800 border-gray-200 dark:border-gray-700':
            !isConnected && !isConnecting,
        }"
      >
        <div class="flex items-center gap-2">
          <span class="text-sm font-medium text-gray-900 dark:text-gray-100">
            {{ $t('INBOX_MGMT.ADD.WHATSAPP_WEB.STATUS') }}:
          </span>
          <span class="text-sm text-gray-700 dark:text-gray-300">
            {{
              isConnected
                ? $t('INBOX_MGMT.ADD.WHATSAPP_WEB.STATUS_CONNECTED')
                : isConnecting
                  ? $t('INBOX_MGMT.ADD.WHATSAPP_WEB.STATUS_CONNECTING')
                  : $t('INBOX_MGMT.ADD.WHATSAPP_WEB.STATUS_DISCONNECTED')
            }}
          </span>
        </div>
        <div
          v-if="channel.phone_number"
          class="mt-2 text-sm text-gray-600 dark:text-gray-400"
        >
          {{ $t('INBOX_MGMT.ADD.WHATSAPP_WEB.PHONE_NUMBER') }}:
          {{ channel.phone_number }}
        </div>
      </div>

      <!-- QR Code Display -->
      <div
        v-if="showQrCode"
        class="mb-6 p-6 rounded-lg border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800"
      >
        <div class="text-center">
          <h3 class="mb-4 text-lg font-medium text-gray-900 dark:text-gray-100">
            {{ $t('INBOX_MGMT.ADD.WHATSAPP_WEB.QR_CODE.TITLE') }}
          </h3>
          <p class="mb-4 text-sm text-gray-600 dark:text-gray-400">
            {{ $t('INBOX_MGMT.ADD.WHATSAPP_WEB.QR_CODE.DESCRIPTION') }}
          </p>
          <div class="flex justify-center mb-4">
            <div
              v-if="qrCode"
              class="p-4 bg-white dark:bg-gray-900 rounded-lg border-2 border-gray-300 dark:border-gray-600"
            >
              <img
                :src="`data:image/png;base64,${qrCode}`"
                alt="QR Code"
                class="w-64 h-64"
              />
            </div>
            <div
              v-else
              class="flex items-center justify-center w-64 h-64 border-2 border-gray-300 dark:border-gray-600 rounded-lg bg-gray-50 dark:bg-gray-900"
            >
              <p class="text-sm text-gray-500 dark:text-gray-400">
                {{ $t('INBOX_MGMT.ADD.WHATSAPP_WEB.WAITING_FOR_QR') }}
              </p>
            </div>
          </div>
          <p class="mb-4 text-xs text-gray-500 dark:text-gray-400">
            {{ $t('INBOX_MGMT.ADD.WHATSAPP_WEB.QR_CODE.EXPIRES_IN') }}
          </p>
          <Button
            variant="outline"
            :label="$t('INBOX_MGMT.ADD.WHATSAPP_WEB.QR_CODE.REGENERATE')"
            @click="regenerateQrCode"
          />
        </div>
      </div>

      <!-- Connected Message -->
      <div
        v-if="isConnected"
        class="p-4 rounded-lg bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800"
      >
        <p class="text-sm text-green-800 dark:text-green-200">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP_WEB.CONNECTED_MESSAGE') }}
        </p>
      </div>
    </div>
  </div>
</template>

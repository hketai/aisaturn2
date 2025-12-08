<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import whatsappWebChannelAPI from 'dashboard/api/whatsappWeb/channel';

const props = defineProps({
  inbox: {
    type: Object,
    required: true,
  },
});

const { t } = useI18n();
const route = useRoute();

const qrCode = ref(null);
const status = ref('disconnected');
const isLoading = ref(false);
const qrCodeExpiresAt = ref(null);
const qrCodePollingInterval = ref(null);

const channelId = computed(
  () => props.inbox.channel_id || props.inbox.channel?.id
);
// Get accountId from route params (more reliable than inbox.account_id)
const accountId = computed(
  () => route.params.accountId || props.inbox.account_id
);
const isConnected = computed(() => status.value === 'connected');
const isDisconnected = computed(() => status.value === 'disconnected');
const showQrCode = computed(() => qrCode.value && !isConnected.value);

const startPollingQrCode = async () => {
  if (qrCodePollingInterval.value) {
    clearInterval(qrCodePollingInterval.value);
  }

  const channelIdStr = String(channelId.value);

  // Fetch QR code immediately
  try {
    const response = await whatsappWebChannelAPI.getQrCode({
      accountId: accountId.value,
      channelId: channelIdStr,
    });

    const qrData = response.data || response;
    if (qrData?.qr_code) {
      qrCode.value = qrData.qr_code;
      qrCodeExpiresAt.value = qrData.expires_at;
      status.value = 'connecting';
    }
  } catch (error) {
    // QR code not available yet
  }

  // Poll for status and QR code
  qrCodePollingInterval.value = setInterval(async () => {
    try {
      const statusResponse = await whatsappWebChannelAPI.getStatus({
        accountId: accountId.value,
        channelId: channelIdStr,
      });

      const statusData = statusResponse.data || statusResponse;

      if (statusData?.status === 'connected') {
        clearInterval(qrCodePollingInterval.value);
        qrCodePollingInterval.value = null;
        qrCode.value = null;
        status.value = 'connected';
        useAlert(
          t('INBOX_MGMT.EDIT.WHATSAPP_WEB.CONNECTED_SUCCESS') ||
            'WhatsApp Web bağlantısı başarılı!'
        );
        // Reload page to reflect new status
        setTimeout(() => window.location.reload(), 1500);
        return;
      }

      status.value = statusData.status || 'disconnected';

      // Fetch QR code if expired or not available
      const isExpired =
        qrCodeExpiresAt.value && new Date(qrCodeExpiresAt.value) < new Date();
      if (!qrCode.value || isExpired) {
        try {
          const qrResponse = await whatsappWebChannelAPI.getQrCode({
            accountId: accountId.value,
            channelId: channelIdStr,
          });

          const qrData = qrResponse.data || qrResponse;
          if (qrData?.qr_code) {
            qrCode.value = qrData.qr_code;
            qrCodeExpiresAt.value = qrData.expires_at;
          }
        } catch (qrError) {
          // QR code not available
        }
      }
    } catch (error) {
      // Continue polling
    }
  }, 2000);
};

const reconnect = async () => {
  if (!channelId.value) return;

  isLoading.value = true;
  qrCode.value = null;

  try {
    // Stop existing client
    try {
      await whatsappWebChannelAPI.stop({
        accountId: accountId.value,
        channelId: String(channelId.value),
      });
    } catch (stopError) {
      // Ignore stop errors
    }

    await new Promise(resolve => setTimeout(resolve, 1000));

    // Start client
    await whatsappWebChannelAPI.start({
      accountId: accountId.value,
      channelId: String(channelId.value),
    });

    status.value = 'connecting';
    await startPollingQrCode();
    useAlert(
      t('INBOX_MGMT.EDIT.WHATSAPP_WEB.QR_GENERATING') ||
        'QR kodu oluşturuluyor...'
    );
  } catch (error) {
    const errorMessage = error?.response?.data?.error || error?.message;
    useAlert(errorMessage || 'Bağlantı hatası');
  } finally {
    isLoading.value = false;
  }
};

onMounted(async () => {
  // Check current status
  if (channelId.value) {
    try {
      const statusResponse = await whatsappWebChannelAPI.getStatus({
        accountId: accountId.value,
        channelId: String(channelId.value),
      });
      const statusData = statusResponse.data || statusResponse;
      status.value = statusData?.status || 'disconnected';
    } catch (error) {
      status.value = 'disconnected';
    }
  }
});

onUnmounted(() => {
  if (qrCodePollingInterval.value) {
    clearInterval(qrCodePollingInterval.value);
  }
});
</script>

<template>
  <div class="mb-6 p-6 rounded-lg border border-n-slate-4 bg-n-slate-1">
    <div class="flex items-center gap-3 mb-4">
      <Icon
        :icon="isConnected ? 'i-lucide-check-circle' : 'i-lucide-alert-circle'"
        :class="isConnected ? 'text-n-teal-11' : 'text-n-ruby-11'"
        class="w-6 h-6"
      />
      <h3 class="text-lg font-medium text-n-slate-12">
        {{
          isConnected ? 'WhatsApp Web Bağlı' : 'WhatsApp Web Bağlantısı Gerekli'
        }}
      </h3>
    </div>

    <!-- Connected State -->
    <div
      v-if="isConnected"
      class="p-4 rounded-lg bg-n-teal-9/20 border border-n-teal-9"
    >
      <p class="text-sm text-n-teal-11">
        WhatsApp Web bağlantınız aktif. Mesaj gönderip alabilirsiniz.
      </p>
    </div>

    <!-- Disconnected State -->
    <div v-else>
      <p class="mb-4 text-sm text-n-slate-11">
        WhatsApp Web bağlantınız kopmuş. Yeniden bağlanmak için aşağıdaki butona
        tıklayın ve QR kodu telefonunuzla tarayın.
      </p>

      <!-- QR Code Display -->
      <div v-if="showQrCode" class="mb-4 text-center">
        <div
          class="inline-block p-4 bg-white rounded-lg border-2 border-n-slate-4"
        >
          <img
            :src="`data:image/png;base64,${qrCode}`"
            alt="QR Code"
            class="w-64 h-64"
          />
        </div>
        <p class="mt-2 text-xs text-n-slate-11">
          QR kodu WhatsApp uygulamasından tarayın
        </p>
      </div>

      <!-- Loading State -->
      <div
        v-else-if="isLoading || status === 'connecting'"
        class="mb-4 flex flex-col items-center justify-center py-8"
      >
        <Icon
          icon="i-lucide-loader-2"
          class="w-8 h-8 text-n-blue-11 mb-3 animate-spin"
        />
        <p class="text-sm text-n-slate-11">QR kodu oluşturuluyor...</p>
      </div>

      <!-- Reconnect Button -->
      <Button
        :is-loading="isLoading"
        :disabled="isLoading"
        :label="showQrCode ? 'QR Kodunu Yenile' : 'Yeniden Bağlan ve QR Göster'"
        icon="i-lucide-refresh-cw"
        @click="reconnect"
      />
    </div>
  </div>
</template>

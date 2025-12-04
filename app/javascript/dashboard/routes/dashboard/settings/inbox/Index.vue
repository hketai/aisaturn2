<script setup>
import { computed, ref, onUnmounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Avatar from 'next/avatar/Avatar.vue';
import { useAdmin } from 'dashboard/composables/useAdmin';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import {
  useMapGetter,
  useStoreGetters,
  useStore,
} from 'dashboard/composables/store';
import ChannelName from './components/ChannelName.vue';
import ChannelIcon from 'next/icon/ChannelIcon.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Modal from 'dashboard/components/Modal.vue';
import whatsappWebChannelAPI from 'dashboard/api/whatsappWeb/channel';
import { useRoute } from 'vue-router';

const getters = useStoreGetters();
const store = useStore();
const { t } = useI18n();
const { isAdmin } = useAdmin();
const route = useRoute();

const showDeletePopup = ref(false);
const selectedInbox = ref({});

// WhatsApp Web QR Modal
const showQrModal = ref(false);
const selectedWhatsappInbox = ref(null);
const qrCode = ref(null);
const qrLoading = ref(false);
const qrPollingInterval = ref(null);
const qrStatus = ref('disconnected');

const inboxes = useMapGetter('inboxes/getInboxes');

const inboxesList = computed(() => {
  return inboxes.value?.slice().sort((a, b) => a.name.localeCompare(b.name));
});

const uiFlags = computed(() => getters['inboxes/getUIFlags'].value);

const deleteConfirmText = computed(
  () => `${t('INBOX_MGMT.DELETE.CONFIRM.YES')} ${selectedInbox.value.name}`
);

const deleteRejectText = computed(
  () => `${t('INBOX_MGMT.DELETE.CONFIRM.NO')} ${selectedInbox.value.name}`
);

const confirmDeleteMessage = computed(
  () => `${t('INBOX_MGMT.DELETE.CONFIRM.MESSAGE')} ${selectedInbox.value.name}?`
);
const confirmPlaceHolderText = computed(
  () =>
    `${t('INBOX_MGMT.DELETE.CONFIRM.PLACE_HOLDER', {
      inboxName: selectedInbox.value.name,
    })}`
);

const deleteInbox = async ({ id }) => {
  try {
    await store.dispatch('inboxes/delete', id);
    useAlert(t('INBOX_MGMT.DELETE.API.SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(t('INBOX_MGMT.DELETE.API.ERROR_MESSAGE'));
  }
};
const closeDelete = () => {
  showDeletePopup.value = false;
  selectedInbox.value = {};
};

const confirmDeletion = () => {
  deleteInbox(selectedInbox.value);
  closeDelete();
};
const openDelete = inbox => {
  showDeletePopup.value = true;
  selectedInbox.value = inbox;
};

const isWhatsappWeb = inbox => inbox.channel_type === 'Channel::WhatsappWeb';

const formatPhoneNumber = number => {
  if (!number) return '';
  if (number.startsWith('+')) return number;
  return `+${number}`;
};

const whatsappWebStatusMeta = status => {
  const map = {
    connected: {
      label: t('INBOX_MGMT.WHATSAPP_WEB.STATUS.CONNECTED'),
      class: 'bg-g-success-subtle text-g-success',
    },
    connecting: {
      label: t('INBOX_MGMT.WHATSAPP_WEB.STATUS.CONNECTING'),
      class: 'bg-n-warning-subtle text-n-warning',
    },
    disconnected: {
      label: t('INBOX_MGMT.WHATSAPP_WEB.STATUS.DISCONNECTED'),
      class: 'bg-n-ruby-subtle text-n-ruby',
    },
    disconnected_qr_expired: {
      label: t('INBOX_MGMT.WHATSAPP_WEB.STATUS.QR_EXPIRED'),
      class: 'bg-n-ruby-subtle text-n-ruby',
    },
  };

  return (
    map[status] || {
      label: t('INBOX_MGMT.WHATSAPP_WEB.STATUS.UNKNOWN'),
      class: 'bg-n-muted-subtle text-n-slate-11',
    }
  );
};

const shouldShowWhatsappReconnect = inbox =>
  isWhatsappWeb(inbox) && inbox.whatsapp_web_status !== 'connected';

const handleWhatsappWebReconnect = async inbox => {
  selectedWhatsappInbox.value = inbox;
  showQrModal.value = true;
  qrCode.value = null;
  qrStatus.value = 'connecting';
  qrLoading.value = true;

  const accountId = route.params.accountId;
  const channelId = inbox.channel_id;

  try {
    // Stop existing client first
    try {
      await whatsappWebChannelAPI.stop({ accountId, channelId: String(channelId) });
    } catch (e) {
      // Ignore stop errors
    }

    await new Promise(resolve => setTimeout(resolve, 1000));

    // Start client
    await whatsappWebChannelAPI.start({ accountId, channelId: String(channelId) });

    // Start polling for QR code
    startQrPolling(accountId, channelId);
  } catch (error) {
    useAlert(error?.response?.data?.error || 'Bağlantı hatası');
    qrLoading.value = false;
  }
};

const startQrPolling = async (accountId, channelId) => {
  // Clear existing interval
  if (qrPollingInterval.value) {
    clearInterval(qrPollingInterval.value);
  }

  // Fetch QR immediately
  try {
    const response = await whatsappWebChannelAPI.getQrCode({
      accountId,
      channelId: String(channelId),
    });
    const qrData = response.data || response;
    if (qrData?.qr_code) {
      qrCode.value = qrData.qr_code;
      qrLoading.value = false;
    }
  } catch (e) {
    // QR not ready yet
  }

  // Poll every 2 seconds
  qrPollingInterval.value = setInterval(async () => {
    try {
      // Check status
      const statusResponse = await whatsappWebChannelAPI.getStatus({
        accountId,
        channelId: String(channelId),
      });
      const statusData = statusResponse.data || statusResponse;

      if (statusData?.status === 'connected') {
        clearInterval(qrPollingInterval.value);
        qrPollingInterval.value = null;
        qrStatus.value = 'connected';
        useAlert('WhatsApp Web bağlantısı başarılı!');
        
        // Refresh inboxes and close modal after delay
        await store.dispatch('inboxes/get');
        setTimeout(() => {
          showQrModal.value = false;
        }, 1500);
        return;
      }

      // Fetch QR if needed
      if (!qrCode.value) {
        const qrResponse = await whatsappWebChannelAPI.getQrCode({
          accountId,
          channelId: String(channelId),
        });
        const qrData = qrResponse.data || qrResponse;
        if (qrData?.qr_code) {
          qrCode.value = qrData.qr_code;
          qrLoading.value = false;
        }
      }
    } catch (e) {
      // Continue polling
    }
  }, 2000);
};

const closeQrModal = () => {
  showQrModal.value = false;
  if (qrPollingInterval.value) {
    clearInterval(qrPollingInterval.value);
    qrPollingInterval.value = null;
  }
  qrCode.value = null;
  selectedWhatsappInbox.value = null;
};

const regenerateQr = async () => {
  if (!selectedWhatsappInbox.value) return;
  
  qrCode.value = null;
  qrLoading.value = true;
  
  const accountId = route.params.accountId;
  const channelId = selectedWhatsappInbox.value.channel_id;

  try {
    await whatsappWebChannelAPI.stop({ accountId, channelId: String(channelId) });
    await new Promise(resolve => setTimeout(resolve, 1000));
    await whatsappWebChannelAPI.start({ accountId, channelId: String(channelId) });
    startQrPolling(accountId, channelId);
  } catch (error) {
    useAlert(error?.response?.data?.error || 'QR yenileme hatası');
    qrLoading.value = false;
  }
};

onUnmounted(() => {
  if (qrPollingInterval.value) {
    clearInterval(qrPollingInterval.value);
  }
});
</script>

<template>
  <SettingsLayout
    :no-records-found="!inboxesList.length"
    :no-records-message="$t('INBOX_MGMT.LIST.404')"
    :is-loading="uiFlags.isFetching"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('INBOX_MGMT.HEADER')"
        :description="$t('INBOX_MGMT.DESCRIPTION')"
        :link-text="$t('INBOX_MGMT.LEARN_MORE')"
        feature-name="inboxes"
      >
        <template #actions>
          <router-link v-if="isAdmin" :to="{ name: 'settings_inbox_new' }">
            <Button
              icon="i-lucide-circle-plus"
              :label="$t('SETTINGS.INBOXES.NEW_INBOX')"
            />
          </router-link>
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <div class="w-full max-w-[60rem] mx-auto py-4">
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          <div
            v-for="inbox in inboxesList"
            :key="inbox.id"
            class="group relative bg-n-solid-2 border border-n-weak rounded-xl p-5 hover:border-n-slate-7 hover:shadow-md transition-all duration-200"
          >
            <!-- Card Header -->
            <div class="flex items-start gap-4">
              <div
                v-if="inbox.avatar_url"
                class="bg-n-alpha-3 rounded-xl size-14 p-2 flex items-center justify-center ring-1 ring-n-weak"
              >
                <Avatar
                  :src="inbox.avatar_url"
                  :name="inbox.name"
                  :size="40"
                  rounded-full
                />
              </div>
              <div
                v-else
                class="size-14 flex justify-center items-center bg-n-alpha-3 rounded-xl ring-1 ring-n-weak"
              >
                <ChannelIcon class="size-7 text-n-slate-10" :inbox="inbox" />
              </div>
              <div class="flex-1 min-w-0">
                <h3 class="font-semibold text-n-slate-12 capitalize truncate">
                  {{ inbox.name }}
                </h3>
                <ChannelName
                  :channel-type="inbox.channel_type"
                  :medium="inbox.medium"
                  class="text-sm text-n-slate-11"
                />
              </div>
            </div>

            <!-- WhatsApp Web Status -->
            <div
              v-if="isWhatsappWeb(inbox)"
              class="mt-4 flex flex-wrap items-center gap-2"
            >
              <span
                class="px-2.5 py-1 text-xs font-medium rounded-full"
                :class="whatsappWebStatusMeta(inbox.whatsapp_web_status).class"
              >
                {{ whatsappWebStatusMeta(inbox.whatsapp_web_status).label }}
              </span>
              <span
                v-if="formatPhoneNumber(inbox.whatsapp_web_phone_number)"
                class="text-xs text-n-slate-11"
              >
                {{
                  t('INBOX_MGMT.WHATSAPP_WEB.CONNECTED_TO', {
                    phone: formatPhoneNumber(inbox.whatsapp_web_phone_number),
                  })
                }}
              </span>
            </div>

            <!-- Card Actions -->
            <div
              class="mt-4 pt-4 border-t border-n-weak flex items-center justify-between"
            >
              <Button
                v-if="shouldShowWhatsappReconnect(inbox) && isAdmin"
                icon="i-lucide-qr-code"
                xs
                slate
                :label="$t('INBOX_MGMT.WHATSAPP_WEB.RECONNECT')"
                @click="handleWhatsappWebReconnect(inbox)"
              />
              <span v-else />
              <div class="flex gap-2">
                <router-link
                  :to="{
                    name: 'settings_inbox_show',
                    params: { inboxId: inbox.id },
                  }"
                >
                  <Button
                    v-if="isAdmin"
                    v-tooltip.top="$t('INBOX_MGMT.SETTINGS')"
                    icon="i-lucide-settings"
                    slate
                    xs
                    faded
                  />
                </router-link>
                <Button
                  v-if="isAdmin"
                  v-tooltip.top="$t('INBOX_MGMT.DELETE.BUTTON_TEXT')"
                  icon="i-lucide-trash-2"
                  xs
                  ruby
                  faded
                  @click="openDelete(inbox)"
                />
              </div>
            </div>
          </div>
        </div>
      </div>
    </template>

    <woot-confirm-delete-modal
      v-if="showDeletePopup"
      v-model:show="showDeletePopup"
      :title="$t('INBOX_MGMT.DELETE.CONFIRM.TITLE')"
      :message="confirmDeleteMessage"
      :confirm-text="deleteConfirmText"
      :reject-text="deleteRejectText"
      :confirm-value="selectedInbox.name"
      :confirm-place-holder-text="confirmPlaceHolderText"
      @on-confirm="confirmDeletion"
      @on-close="closeDelete"
    />

    <!-- WhatsApp Web QR Modal -->
    <Modal
      v-model:show="showQrModal"
      :on-close="closeQrModal"
      size="small"
    >
      <div class="p-6">
        <div class="text-center mb-6">
          <div class="inline-flex items-center justify-center w-12 h-12 rounded-full bg-n-teal-9/20 mb-4">
            <Icon icon="i-ri-whatsapp-fill" class="w-6 h-6 text-n-teal-11" />
          </div>
          <h3 class="text-lg font-semibold text-n-slate-12">
            WhatsApp Web Bağlantısı
          </h3>
          <p class="text-sm text-n-slate-11 mt-1">
            {{ selectedWhatsappInbox?.name }}
          </p>
        </div>

        <!-- Connected State -->
        <div v-if="qrStatus === 'connected'" class="text-center py-8">
          <Icon icon="i-lucide-check-circle" class="w-16 h-16 text-n-teal-11 mx-auto mb-4" />
          <p class="text-n-teal-11 font-medium">Bağlantı Başarılı!</p>
        </div>

        <!-- QR Code Display -->
        <div v-else class="text-center">
          <!-- Loading -->
          <div v-if="qrLoading && !qrCode" class="py-12">
            <Icon icon="i-lucide-loader-2" class="w-10 h-10 text-n-blue-11 mx-auto mb-4 animate-spin" />
            <p class="text-sm text-n-slate-11">QR kodu oluşturuluyor...</p>
          </div>

          <!-- QR Code -->
          <div v-else-if="qrCode" class="space-y-4">
            <div class="inline-block p-4 bg-white rounded-xl border-2 border-n-slate-4">
              <img
                :src="`data:image/png;base64,${qrCode}`"
                alt="WhatsApp QR Code"
                class="w-56 h-56"
              />
            </div>
            <p class="text-sm text-n-slate-11">
              WhatsApp'ı açın → Ayarlar → Bağlı Cihazlar → Cihaz Bağla
            </p>
            <Button
              variant="outline"
              icon="i-lucide-refresh-cw"
              label="QR Kodunu Yenile"
              @click="regenerateQr"
            />
          </div>

          <!-- No QR Available -->
          <div v-else class="py-8">
            <p class="text-sm text-n-slate-11 mb-4">QR kodu alınamadı</p>
            <Button
              icon="i-lucide-refresh-cw"
              label="Tekrar Dene"
              @click="regenerateQr"
            />
          </div>
        </div>

        <!-- Close Button -->
        <div class="mt-6 pt-4 border-t border-n-weak text-center">
          <Button
            variant="outline"
            label="Kapat"
            @click="closeQrModal"
          />
        </div>
      </div>
    </Modal>
  </SettingsLayout>
</template>

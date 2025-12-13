<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Avatar from 'next/avatar/Avatar.vue';
import { useAdmin } from 'dashboard/composables/useAdmin';
import SettingsLayout from '../SettingsLayout.vue';
import {
  useMapGetter,
  useStoreGetters,
  useStore,
} from 'dashboard/composables/store';
import ChannelIcon from 'next/icon/ChannelIcon.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'next/icon/Icon.vue';
import { useRouter } from 'vue-router';

const getters = useStoreGetters();
const store = useStore();
const { t } = useI18n();
const { isAdmin } = useAdmin();
const router = useRouter();

const showDeletePopup = ref(false);
const selectedInbox = ref({});

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
      class: 'bg-n-teal-3 text-n-teal-11 border-n-teal-6',
      icon: 'i-lucide-check-circle',
    },
    connecting: {
      label: t('INBOX_MGMT.WHATSAPP_WEB.STATUS.CONNECTING'),
      class: 'bg-n-amber-3 text-n-amber-11 border-n-amber-6',
      icon: 'i-lucide-loader',
    },
    disconnected: {
      label: t('INBOX_MGMT.WHATSAPP_WEB.STATUS.DISCONNECTED'),
      class: 'bg-n-ruby-3 text-n-ruby-11 border-n-ruby-6',
      icon: 'i-lucide-x-circle',
    },
    disconnected_qr_expired: {
      label: t('INBOX_MGMT.WHATSAPP_WEB.STATUS.QR_EXPIRED'),
      class: 'bg-n-ruby-3 text-n-ruby-11 border-n-ruby-6',
      icon: 'i-lucide-alert-circle',
    },
  };

  return (
    map[status] || {
      label: t('INBOX_MGMT.WHATSAPP_WEB.STATUS.UNKNOWN'),
      class: 'bg-n-slate-3 text-n-slate-11 border-n-slate-6',
      icon: 'i-lucide-help-circle',
    }
  );
};

const shouldShowWhatsappReconnect = inbox =>
  isWhatsappWeb(inbox) && inbox.whatsapp_web_status !== 'connected';

const handleWhatsappWebReconnect = inbox => {
  router.push({
    name: 'settings_inbox_show',
    params: { inboxId: inbox.id },
    query: { reconnect: 'whatsapp_web' },
  });
};

const getChannelColor = channelType => {
  const colors = {
    'Channel::WebWidget': 'bg-n-blue-3 text-n-blue-11',
    'Channel::FacebookPage': 'bg-n-blue-3 text-n-blue-11',
    'Channel::Whatsapp': 'bg-n-teal-3 text-n-teal-11',
    'Channel::WhatsappWeb': 'bg-n-teal-3 text-n-teal-11',
    'Channel::Email': 'bg-n-amber-3 text-n-amber-11',
    'Channel::Telegram': 'bg-n-blue-3 text-n-blue-11',
    'Channel::Line': 'bg-n-teal-3 text-n-teal-11',
    'Channel::Sms': 'bg-n-violet-3 text-n-violet-11',
    'Channel::Api': 'bg-n-slate-3 text-n-slate-11',
  };
  return colors[channelType] || 'bg-n-slate-3 text-n-slate-11';
};

const getChannelTypeName = channelType => {
  const names = {
    'Channel::WebWidget': 'Web Widget',
    'Channel::FacebookPage': 'Facebook',
    'Channel::Whatsapp': 'WhatsApp',
    'Channel::WhatsappWeb': 'WhatsApp Web',
    'Channel::Email': 'E-posta',
    'Channel::Telegram': 'Telegram',
    'Channel::Line': 'Line',
    'Channel::Sms': 'SMS',
    'Channel::Api': 'API',
  };
  return names[channelType] || channelType;
};

const goToSettings = inbox => {
  router.push({
    name: 'settings_inbox_show',
    params: { inboxId: inbox.id },
  });
};
</script>

<template>
  <SettingsLayout
    :no-records-found="!inboxesList.length"
    :no-records-message="$t('INBOX_MGMT.LIST.404')"
    :is-loading="uiFlags.isFetching"
  >
    <template #header>
      <div class="flex items-center justify-between w-full">
        <div>
          <h1 class="text-2xl font-semibold text-n-slate-12">
            {{ $t('INBOX_MGMT.HEADER') }}
          </h1>
          <p class="mt-1 text-sm text-n-slate-11">
            Müşterilerinizle iletişim kurmak için kullandığınız kanalları yönetin
          </p>
        </div>
        <router-link v-if="isAdmin" :to="{ name: 'settings_inbox_new' }">
          <Button
            icon="i-lucide-plus"
            :label="$t('SETTINGS.INBOXES.NEW_INBOX')"
          />
        </router-link>
      </div>
    </template>

    <template #body>
      <!-- Stats Cards -->
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
        <div class="p-4 bg-n-solid-1 rounded-xl border border-n-weak">
          <div class="flex items-center gap-3">
            <div
              class="w-10 h-10 rounded-lg bg-n-blue-3 flex items-center justify-center"
            >
              <Icon icon="i-lucide-inbox" class="w-5 h-5 text-n-blue-11" />
            </div>
            <div>
              <p class="text-2xl font-bold text-n-slate-12">
                {{ inboxesList?.length || 0 }}
              </p>
              <p class="text-xs text-n-slate-11">Toplam Kanal</p>
            </div>
          </div>
        </div>
        <div class="p-4 bg-n-solid-1 rounded-xl border border-n-weak">
          <div class="flex items-center gap-3">
            <div
              class="w-10 h-10 rounded-lg bg-n-teal-3 flex items-center justify-center"
            >
              <Icon icon="i-lucide-check-circle" class="w-5 h-5 text-n-teal-11" />
            </div>
            <div>
              <p class="text-2xl font-bold text-n-slate-12">
                {{
                  inboxesList?.filter(
                    i =>
                      !isWhatsappWeb(i) || i.whatsapp_web_status === 'connected'
                  ).length || 0
                }}
              </p>
              <p class="text-xs text-n-slate-11">Aktif Kanal</p>
            </div>
          </div>
        </div>
        <div class="p-4 bg-n-solid-1 rounded-xl border border-n-weak">
          <div class="flex items-center gap-3">
            <div
              class="w-10 h-10 rounded-lg bg-n-teal-3 flex items-center justify-center"
            >
              <Icon icon="i-lucide-message-circle" class="w-5 h-5 text-n-teal-11" />
            </div>
            <div>
              <p class="text-2xl font-bold text-n-slate-12">
                {{
                  inboxesList?.filter(
                    i =>
                      i.channel_type === 'Channel::Whatsapp' ||
                      i.channel_type === 'Channel::WhatsappWeb'
                  ).length || 0
                }}
              </p>
              <p class="text-xs text-n-slate-11">WhatsApp</p>
            </div>
          </div>
        </div>
        <div class="p-4 bg-n-solid-1 rounded-xl border border-n-weak">
          <div class="flex items-center gap-3">
            <div
              class="w-10 h-10 rounded-lg bg-n-amber-3 flex items-center justify-center"
            >
              <Icon icon="i-lucide-globe" class="w-5 h-5 text-n-amber-11" />
            </div>
            <div>
              <p class="text-2xl font-bold text-n-slate-12">
                {{
                  inboxesList?.filter(
                    i => i.channel_type === 'Channel::WebWidget'
                  ).length || 0
                }}
              </p>
              <p class="text-xs text-n-slate-11">Web Widget</p>
            </div>
          </div>
        </div>
      </div>

      <!-- Inbox Cards Grid -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        <div
          v-for="inbox in inboxesList"
          :key="inbox.id"
          class="group relative bg-n-solid-1 rounded-xl border border-n-weak hover:border-n-brand/50 hover:shadow-lg transition-all duration-200 overflow-hidden cursor-pointer"
          @click="goToSettings(inbox)"
        >
          <!-- Card Header -->
          <div class="p-5">
            <div class="flex items-start justify-between gap-3">
              <!-- Icon & Name -->
              <div class="flex items-center gap-3 min-w-0 flex-1">
                <div
                  v-if="inbox.avatar_url"
                  class="w-12 h-12 rounded-xl bg-n-alpha-3 p-1 ring-2 ring-n-solid-1 border border-n-weak shadow-sm flex-shrink-0 overflow-hidden"
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
                  :class="[
                    'w-12 h-12 rounded-xl flex items-center justify-center flex-shrink-0',
                    getChannelColor(inbox.channel_type),
                  ]"
                >
                  <ChannelIcon class="w-6 h-6" :inbox="inbox" />
                </div>
                <div class="min-w-0 flex-1">
                  <h3
                    class="font-semibold text-n-slate-12 truncate group-hover:text-n-brand transition-colors"
                  >
                    {{ inbox.name }}
                  </h3>
                  <span
                    class="inline-flex items-center px-2 py-0.5 text-xs font-medium rounded-md mt-1"
                    :class="getChannelColor(inbox.channel_type)"
                  >
                    {{ getChannelTypeName(inbox.channel_type) }}
                  </span>
                </div>
              </div>

              <!-- Actions -->
              <div
                class="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity"
                @click.stop
              >
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
                  @click.stop="openDelete(inbox)"
                />
              </div>
            </div>

            <!-- WhatsApp Web Status -->
            <div v-if="isWhatsappWeb(inbox)" class="mt-4 pt-4 border-t border-n-weak">
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-2">
                  <span
                    class="inline-flex items-center gap-1.5 px-2.5 py-1 text-xs font-medium rounded-lg border"
                    :class="whatsappWebStatusMeta(inbox.whatsapp_web_status).class"
                  >
                    <Icon
                      :icon="whatsappWebStatusMeta(inbox.whatsapp_web_status).icon"
                      class="w-3.5 h-3.5"
                    />
                    {{ whatsappWebStatusMeta(inbox.whatsapp_web_status).label }}
                  </span>
                </div>
                <Button
                  v-if="shouldShowWhatsappReconnect(inbox) && isAdmin"
                  icon="i-lucide-qr-code"
                  xs
                  slate
                  :label="'Bağlan'"
                  @click.stop="handleWhatsappWebReconnect(inbox)"
                />
              </div>
              <p
                v-if="formatPhoneNumber(inbox.whatsapp_web_phone_number)"
                class="mt-2 text-xs text-n-slate-11 flex items-center gap-1.5"
              >
                <Icon icon="i-lucide-phone" class="w-3.5 h-3.5" />
                {{ formatPhoneNumber(inbox.whatsapp_web_phone_number) }}
              </p>
            </div>
          </div>

          <!-- Hover Indicator -->
          <div
            class="absolute bottom-0 left-0 right-0 h-1 bg-n-brand transform scale-x-0 group-hover:scale-x-100 transition-transform origin-left"
          />
        </div>

        <!-- Add New Inbox Card -->
        <router-link
          v-if="isAdmin"
          :to="{ name: 'settings_inbox_new' }"
          class="group flex flex-col items-center justify-center p-8 bg-n-solid-1 rounded-xl border-2 border-dashed border-n-weak hover:border-n-brand/50 hover:bg-n-alpha-1 transition-all duration-200 min-h-[160px] cursor-pointer"
        >
          <div
            class="w-14 h-14 rounded-xl bg-n-slate-3 group-hover:bg-n-brand/10 flex items-center justify-center mb-3 transition-colors"
          >
            <Icon
              icon="i-lucide-plus"
              class="w-7 h-7 text-n-slate-11 group-hover:text-n-brand transition-colors"
            />
          </div>
          <span
            class="text-sm font-medium text-n-slate-11 group-hover:text-n-brand transition-colors"
          >
            Yeni Kanal Ekle
          </span>
        </router-link>
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
  </SettingsLayout>
</template>

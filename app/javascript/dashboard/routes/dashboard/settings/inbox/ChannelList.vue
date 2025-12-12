<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';

import { useAccount } from 'dashboard/composables/useAccount';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const { t } = useI18n();
const router = useRouter();
const { accountId, currentAccount } = useAccount();

const enabledFeatures = ref({});

const channelList = computed(() => {
  return [
    {
      key: 'whatsapp',
      title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.WHATSAPP.TITLE'),
      description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.WHATSAPP.DESCRIPTION'),
      icon: 'i-lucide-message-circle',
      color: 'bg-green-500',
      iconColor: 'text-white',
      popular: true,
    },
    {
      key: 'instagram',
      title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.INSTAGRAM.TITLE'),
      description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.INSTAGRAM.DESCRIPTION'),
      icon: 'i-lucide-instagram',
      color: 'bg-gradient-to-br from-purple-500 via-pink-500 to-orange-400',
      iconColor: 'text-white',
      popular: true,
    },
    {
      key: 'facebook',
      title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.FACEBOOK.TITLE'),
      description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.FACEBOOK.DESCRIPTION'),
      icon: 'i-lucide-facebook',
      color: 'bg-blue-600',
      iconColor: 'text-white',
      popular: false,
    },
    {
      key: 'website',
      title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.WEBSITE.TITLE'),
      description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.WEBSITE.DESCRIPTION'),
      icon: 'i-lucide-message-square',
      color: 'bg-n-brand',
      iconColor: 'text-white',
      popular: true,
    },
    {
      key: 'email',
      title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.EMAIL.TITLE'),
      description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.EMAIL.DESCRIPTION'),
      icon: 'i-lucide-mail',
      color: 'bg-n-slate-11',
      iconColor: 'text-white',
      popular: false,
    },
    {
      key: 'telegram',
      title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.TELEGRAM.TITLE'),
      description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.TELEGRAM.DESCRIPTION'),
      icon: 'i-lucide-send',
      color: 'bg-sky-500',
      iconColor: 'text-white',
      popular: false,
    },
  ];
});

const popularChannels = computed(() => channelList.value.filter(c => c.popular));
const otherChannels = computed(() => channelList.value.filter(c => !c.popular));

const initializeEnabledFeatures = async () => {
  enabledFeatures.value = currentAccount.value.features;
};

const initChannelAuth = channel => {
  const params = {
    sub_page: channel,
    accountId: accountId.value,
  };
  router.push({ name: 'settings_inboxes_page_channel', params });
};

onMounted(() => {
  initializeEnabledFeatures();
});
</script>

<template>
  <div class="w-full max-w-4xl mx-auto p-8 overflow-auto">
    <!-- Popular Channels -->
    <div class="mb-8">
      <h2 class="text-sm font-semibold text-n-slate-10 uppercase tracking-wide mb-4">
        Popüler Kanallar
      </h2>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <button
          v-for="channel in popularChannels"
          :key="channel.key"
          class="group flex items-center gap-4 p-5 bg-n-slate-2 hover:bg-n-slate-3 border border-n-slate-4 hover:border-n-slate-6 rounded-2xl transition-all duration-200 text-left"
          @click="initChannelAuth(channel.key)"
        >
          <div
            class="w-14 h-14 rounded-xl flex items-center justify-center flex-shrink-0 shadow-lg"
            :class="channel.color"
          >
            <Icon :icon="channel.icon" class="w-7 h-7" :class="channel.iconColor" />
          </div>
          <div class="flex-1 min-w-0">
            <h3 class="text-base font-semibold text-n-slate-12 group-hover:text-n-brand transition-colors">
              {{ channel.title }}
            </h3>
            <p class="text-sm text-n-slate-10 mt-0.5">
              {{ channel.description }}
            </p>
          </div>
          <Icon
            icon="i-lucide-chevron-right"
            class="w-5 h-5 text-n-slate-10 group-hover:text-n-brand group-hover:translate-x-1 transition-all"
          />
        </button>
      </div>
    </div>

    <!-- Other Channels -->
    <div>
      <h2 class="text-sm font-semibold text-n-slate-10 uppercase tracking-wide mb-4">
        Diğer Kanallar
      </h2>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
        <button
          v-for="channel in otherChannels"
          :key="channel.key"
          class="group flex items-center gap-3 p-4 bg-n-slate-2 hover:bg-n-slate-3 border border-n-slate-4 hover:border-n-slate-6 rounded-xl transition-all duration-200 text-left"
          @click="initChannelAuth(channel.key)"
        >
          <div
            class="w-10 h-10 rounded-lg flex items-center justify-center flex-shrink-0"
            :class="channel.color"
          >
            <Icon :icon="channel.icon" class="w-5 h-5" :class="channel.iconColor" />
          </div>
          <div class="flex-1 min-w-0">
            <h3 class="text-sm font-medium text-n-slate-12 group-hover:text-n-brand transition-colors">
              {{ channel.title }}
            </h3>
            <p class="text-xs text-n-slate-10 truncate">
              {{ channel.description }}
            </p>
          </div>
        </button>
      </div>
    </div>
  </div>
</template>

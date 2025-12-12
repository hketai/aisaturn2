<script setup>
import { ref, computed, onBeforeUnmount } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { useEmitter } from 'dashboard/composables/emitter';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import {
  isAConversationRoute,
  isAInboxViewRoute,
  isNotificationRoute,
} from 'dashboard/helper/routeHelpers';
import { useEventListener } from '@vueuse/core';

import Button from 'dashboard/components-next/button/Button.vue';

const { t } = useI18n();
const route = useRoute();

const RECONNECTED_BANNER_TIMEOUT = 2000;

const showNotification = ref(!navigator.onLine);
const isDisconnected = ref(false);
const isReconnecting = ref(false);
const isReconnected = ref(false);
let reconnectTimeout = null;

const bannerText = computed(() => {
  if (isReconnecting.value) return t('NETWORK.NOTIFICATION.RECONNECTING');
  if (isReconnected.value) return t('NETWORK.NOTIFICATION.RECONNECT_SUCCESS');
  return t('NETWORK.NOTIFICATION.OFFLINE');
});

const iconName = computed(() => {
  if (isReconnected.value) return 'i-lucide-wifi';
  if (isReconnecting.value) return 'i-lucide-loader-2';
  return 'i-lucide-wifi-off';
});

const canRefresh = computed(
  () => !isReconnecting.value && !isReconnected.value
);

// Dynamic styling based on status
const statusStyles = computed(() => {
  if (isReconnected.value) {
    return {
      container: 'bg-n-teal-3 border-n-teal-6',
      icon: 'text-n-teal-11',
      text: 'text-n-teal-11',
      iconBg: 'bg-n-teal-4',
    };
  }
  if (isReconnecting.value) {
    return {
      container: 'bg-n-amber-3 border-n-amber-6',
      icon: 'text-n-amber-11 animate-spin',
      text: 'text-n-amber-11',
      iconBg: 'bg-n-amber-4',
    };
  }
  // Offline
  return {
    container: 'bg-n-ruby-3 border-n-ruby-6',
    icon: 'text-n-ruby-11',
    text: 'text-n-ruby-11',
    iconBg: 'bg-n-ruby-4',
  };
});

const refreshPage = () => {
  window.location.reload();
};

const closeNotification = () => {
  showNotification.value = false;
  isReconnected.value = false;
  clearTimeout(reconnectTimeout);
};

const isInAnyOfTheRoutes = routeName => {
  return (
    isAConversationRoute(routeName, true) ||
    isAInboxViewRoute(routeName, true) ||
    isNotificationRoute(routeName, true)
  );
};

const updateWebsocketStatus = () => {
  isDisconnected.value = true;
  showNotification.value = true;
};

const handleReconnectionCompleted = () => {
  isDisconnected.value = false;
  isReconnecting.value = false;
  isReconnected.value = true;
  showNotification.value = true;
  reconnectTimeout = setTimeout(closeNotification, RECONNECTED_BANNER_TIMEOUT);
};

const handleReconnecting = () => {
  if (isInAnyOfTheRoutes(route.name)) {
    isReconnecting.value = true;
    isReconnected.value = false;
    showNotification.value = true;
  } else {
    handleReconnectionCompleted();
  }
};

const updateOnlineStatus = event => {
  if (event.type === 'offline') {
    showNotification.value = true;
  } else if (event.type === 'online' && !isDisconnected.value) {
    handleReconnectionCompleted();
  }
};

useEventListener('online', updateOnlineStatus);
useEventListener('offline', updateOnlineStatus);
useEmitter(BUS_EVENTS.WEBSOCKET_DISCONNECT, updateWebsocketStatus);
useEmitter(
  BUS_EVENTS.WEBSOCKET_RECONNECT_COMPLETED,
  handleReconnectionCompleted
);
useEmitter(BUS_EVENTS.WEBSOCKET_RECONNECT, handleReconnecting);

onBeforeUnmount(() => {
  clearTimeout(reconnectTimeout);
});
</script>

<template>
  <transition name="network-notification-slide" tag="div">
    <div
      v-show="showNotification"
      class="fixed z-50 bottom-6 right-6"
    >
      <div
        class="flex items-center gap-3 px-4 py-3 rounded-xl border shadow-lg backdrop-blur-sm"
        :class="statusStyles.container"
      >
        <!-- Status Icon -->
        <div
          class="w-8 h-8 rounded-lg flex items-center justify-center"
          :class="statusStyles.iconBg"
        >
          <i
            :class="[iconName, statusStyles.icon]"
            class="text-lg"
          />
        </div>

        <!-- Text -->
        <span
          class="text-sm font-medium"
          :class="statusStyles.text"
        >
          {{ bannerText }}
        </span>

        <!-- Actions -->
        <div class="flex items-center gap-1 ml-2">
          <Button
            v-if="canRefresh"
            ghost
            xs
            slate
            icon="i-lucide-refresh-ccw"
            :title="$t('NETWORK.BUTTON.REFRESH')"
            :class="statusStyles.text"
            @click="refreshPage"
          />
          <Button
            ghost
            xs
            slate
            icon="i-lucide-x"
            :class="statusStyles.text"
            @click="closeNotification"
          />
        </div>
      </div>
    </div>
  </transition>
</template>

<style scoped>
.network-notification-slide-enter-active,
.network-notification-slide-leave-active {
  transition: all 0.3s ease;
}

.network-notification-slide-enter-from,
.network-notification-slide-leave-to {
  opacity: 0;
  transform: translateY(20px);
}
</style>

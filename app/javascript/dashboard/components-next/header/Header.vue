<script setup>
import { h, computed, ref, onMounted, onUnmounted, watch } from 'vue';
import { useAccount } from 'dashboard/composables/useAccount';
import { useMapGetter } from 'dashboard/composables/store';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useRouter, useRoute } from 'vue-router';
import { vOnClickOutside } from '@vueuse/components';
import Auth from 'dashboard/api/auth';
import subscriptionsAPI from 'dashboard/api/subscriptions';

import SaturnIcon from 'dashboard/components-next/icon/SaturnIcon.vue';
import Avatar from 'next/avatar/Avatar.vue';

const emit = defineEmits(['showCreateAccountModal']);
// Logo URLs
const LOGO_LIGHT = 'https://aisaturn.co/images/aisaturnkoyu-aciktemaicin.png';
const LOGO_DARK = 'https://aisaturn.co/images/logo_wihte-koyutemaicin.png';

const { accountScopedRoute } = useAccount();
const store = useStore();
const router = useRouter();
const route = useRoute();
const { t } = useI18n();

const activeDropdown = ref(null);
const settingsOpen = ref(false);
const profileOpen = ref(false);
const currentSubscription = ref(null);
const isDarkMode = ref(false);

// Dark mode detection
const checkDarkMode = () => {
  isDarkMode.value =
    document.documentElement.classList.contains('dark') ||
    document.body.classList.contains('dark');
};

// Logo based on theme
const currentLogo = computed(() => {
  return isDarkMode.value ? LOGO_DARK : LOGO_LIGHT;
});

// Navigate to dashboard
const goToDashboard = () => {
  router.push(accountScopedRoute('home'));
};

const currentUser = useMapGetter('getCurrentUser');
const currentUserAvailability = useMapGetter('getCurrentUserAvailability');
const currentAccountId = useMapGetter('getCurrentAccountId');
const inboxes = useMapGetter('inboxes/getInboxes');
const labels = useMapGetter('labels/getLabelsOnSidebar');
const teams = useMapGetter('teams/getMyTeams');

// Availability options
const availabilityStatuses = [
  {
    value: 'online',
    label: 'PROFILE_SETTINGS.FORM.AVAILABILITY.STATUS.ONLINE',
    color: 'bg-n-teal-9',
  },
  {
    value: 'busy',
    label: 'PROFILE_SETTINGS.FORM.AVAILABILITY.STATUS.BUSY',
    color: 'bg-n-ruby-9',
  },
  {
    value: 'offline',
    label: 'PROFILE_SETTINGS.FORM.AVAILABILITY.STATUS.OFFLINE',
    color: 'bg-n-slate-9',
  },
];

const setAvailability = async availability => {
  await store.dispatch('updateAvailability', {
    availability,
    account_id: currentAccountId.value,
  });
};

const fetchCurrentSubscription = async () => {
  try {
    const response = await subscriptionsAPI.current();
    currentSubscription.value = response.data;
  } catch (err) {
    currentSubscription.value = null;
  }
};

watch(currentAccountId, () => {
  fetchCurrentSubscription();
});

// Dark mode observer
let darkModeObserver = null;

onMounted(() => {
  store.dispatch('labels/get');
  store.dispatch('inboxes/get');
  store.dispatch('notifications/unReadCount');
  store.dispatch('teams/get');
  store.dispatch('attributes/get');
  fetchCurrentSubscription();

  // Check dark mode initially
  checkDarkMode();

  // Watch for dark mode changes
  darkModeObserver = new MutationObserver(() => {
    checkDarkMode();
  });

  darkModeObserver.observe(document.documentElement, {
    attributes: true,
    attributeFilter: ['class'],
  });

  darkModeObserver.observe(document.body, {
    attributes: true,
    attributeFilter: ['class'],
  });
});

onUnmounted(() => {
  if (darkModeObserver) {
    darkModeObserver.disconnect();
  }
});

const sortedInboxes = computed(() =>
  inboxes.value.slice().sort((a, b) => a.name.localeCompare(b.name))
);

const toggleDropdown = name => {
  activeDropdown.value = activeDropdown.value === name ? null : name;
  settingsOpen.value = false;
  profileOpen.value = false;
};

const closeDropdowns = () => {
  activeDropdown.value = null;
  settingsOpen.value = false;
  profileOpen.value = false;
};

const toggleSettings = () => {
  settingsOpen.value = !settingsOpen.value;
  activeDropdown.value = null;
  profileOpen.value = false;
};

const toggleProfile = () => {
  profileOpen.value = !profileOpen.value;
  activeDropdown.value = null;
  settingsOpen.value = false;
};

const navigateTo = routeObj => {
  router.push(routeObj);
  closeDropdowns();
};

const isActiveRoute = (routeName, activeOn = []) => {
  const currentRouteName = route.name;
  return currentRouteName === routeName || activeOn.includes(currentRouteName);
};

const mainMenuItems = computed(() => [
  {
    name: 'Conversation',
    label: t('SIDEBAR.CONVERSATIONS'),
    icon: 'i-lucide-message-circle',
    children: [
      {
        name: 'All',
        label: t('SIDEBAR.ALL_CONVERSATIONS'),
        to: accountScopedRoute('home'),
        activeOn: ['inbox_conversation'],
      },
      {
        name: 'Mentions',
        label: t('SIDEBAR.MENTIONED_CONVERSATIONS'),
        to: accountScopedRoute('conversation_mentions'),
        activeOn: ['conversation_through_mentions'],
      },
      {
        name: 'Unattended',
        label: t('SIDEBAR.UNATTENDED_CONVERSATIONS'),
        to: accountScopedRoute('conversation_unattended'),
        activeOn: ['conversation_through_unattended'],
      },
    ],
  },
  {
    name: 'Saturn',
    label: 'Saturn',
    icon: 'saturn',
    children: [
      {
        name: 'Assistants',
        label: t('SIDEBAR.SATURN_ASSISTANTS'),
        to: accountScopedRoute('saturn_assistants_index'),
      },
      {
        name: 'Responses',
        label: t('SIDEBAR.SATURN_RESPONSES'),
        to: accountScopedRoute('saturn_responses_index'),
      },
      {
        name: 'Documents',
        label: t('SIDEBAR.SATURN_DOCUMENTS'),
        to: accountScopedRoute('saturn_documents_index'),
      },
      {
        name: 'Integrations',
        label: t('SIDEBAR.SATURN_INTEGRATIONS'),
        to: accountScopedRoute('saturn_integrations_index'),
      },
    ],
  },
  {
    name: 'Channels',
    label: 'Kanal',
    icon: 'i-lucide-plug',
    to: accountScopedRoute('settings_inbox_list'),
    children: [],
  },
  {
    name: 'Contacts',
    label: t('SIDEBAR.CONTACTS'),
    icon: 'i-lucide-users',
    children: [
      {
        name: 'All Contacts',
        label: t('SIDEBAR.ALL_CONTACTS'),
        to: accountScopedRoute('contacts_dashboard_index', {}, { page: 1 }),
        activeOn: ['contacts_dashboard_index', 'contacts_edit'],
      },
      {
        name: 'Active',
        label: t('SIDEBAR.ACTIVE'),
        to: accountScopedRoute('contacts_dashboard_active'),
        activeOn: ['contacts_dashboard_active'],
      },
      {
        name: 'Labels',
        label: t('SIDEBAR.LABELS'),
        to: accountScopedRoute('labels_list'),
      },
    ],
  },
  {
    name: 'Reports',
    label: t('SIDEBAR.REPORTS'),
    icon: 'i-lucide-trending-up',
    children: [
      {
        name: 'Overview',
        label: t('SIDEBAR.REPORTS_OVERVIEW'),
        to: accountScopedRoute('account_overview_reports'),
      },
      {
        name: 'Conversation',
        label: t('SIDEBAR.REPORTS_CONVERSATION'),
        to: accountScopedRoute('conversation_reports'),
      },
      {
        name: 'Agent',
        label: t('SIDEBAR.REPORTS_AGENT'),
        to: accountScopedRoute('agent_reports_index'),
      },
      {
        name: 'Label',
        label: t('SIDEBAR.REPORTS_LABEL'),
        to: accountScopedRoute('label_reports_index'),
      },
      {
        name: 'Inbox',
        label: t('SIDEBAR.REPORTS_INBOX'),
        to: accountScopedRoute('inbox_reports_index'),
      },
      {
        name: 'Team',
        label: t('SIDEBAR.REPORTS_TEAM'),
        to: accountScopedRoute('team_reports_index'),
      },
      {
        name: 'Bot',
        label: t('SIDEBAR.REPORTS_BOT'),
        to: accountScopedRoute('bot_reports'),
      },
    ],
  },
]);

const settingsItems = computed(() => [
  {
    name: 'Account Settings',
    label: t('SIDEBAR.ACCOUNT_SETTINGS'),
    icon: 'i-lucide-briefcase',
    to: accountScopedRoute('general_settings_index'),
  },
  {
    name: 'Agents',
    label: t('SIDEBAR.AGENTS'),
    icon: 'i-lucide-square-user',
    to: accountScopedRoute('agent_list'),
  },
  {
    name: 'Teams',
    label: t('SIDEBAR.TEAMS'),
    icon: 'i-lucide-users',
    to: accountScopedRoute('settings_teams_list'),
  },
]);

const subscriptionPlanName = computed(
  () => currentSubscription.value?.plan?.name || 'Free'
);

const userName = computed(
  () => currentUser.value?.available_name || currentUser.value?.name || 'User'
);
const userEmail = computed(() => currentUser.value?.email || '');
const userAvatar = computed(() => currentUser.value?.avatar_url);
const isSuperAdmin = computed(() => currentUser.value?.type === 'SuperAdmin');

const goToProfileSettings = () => {
  router.push({ name: 'profile_settings_index' });
  closeDropdowns();
};

const goToSubscriptionPage = () => {
  router.push({
    name: 'subscriptions_index',
    params: { accountId: currentAccountId.value },
  });
  closeDropdowns();
};

const openAppearanceSettings = () => {
  const ninja = document.querySelector('ninja-keys');
  if (ninja) {
    ninja.open({ parent: 'appearance_settings' });
  }
  closeDropdowns();
};

const openSuperAdmin = () => {
  window.open('/super_admin', '_blank');
  closeDropdowns();
};

const logout = () => {
  Auth.logout();
};
</script>

<template>
  <header
    v-on-click-outside="closeDropdowns"
    class="bg-n-solid-2 border-b border-n-weak flex items-center justify-between px-4 h-14 flex-shrink-0 z-50"
  >
    <!-- Left: Logo -->
    <div class="flex items-center gap-2">
      <div
        class="flex items-center cursor-pointer hover:opacity-80 transition-opacity"
        @click="goToDashboard"
      >
        <img :src="currentLogo" alt="AISATURN" class="h-5 w-auto" />
      </div>
    </div>

    <!-- Center: Main Navigation -->
    <nav class="flex items-center gap-1">
      <div v-for="item in mainMenuItems" :key="item.name" class="relative">
        <!-- Direct link (no children) -->
        <button
          v-if="!item.children?.length"
          class="flex items-center gap-2 px-3 py-2 rounded-lg text-sm font-medium transition-colors hover:bg-n-alpha-2"
          :class="{ 'bg-n-alpha-2': isActiveRoute(item.to?.name) }"
          @click="navigateTo(item.to)"
        >
          <SaturnIcon v-if="item.icon === 'saturn'" class="size-4" />
          <span v-else class="size-4" :class="[item.icon]" />
          <span>{{ item.label }}</span>
        </button>
        <!-- Dropdown menu -->
        <button
          v-else
          class="flex items-center gap-2 px-3 py-2 rounded-lg text-sm font-medium transition-colors hover:bg-n-alpha-2"
          :class="{ 'bg-n-alpha-2': activeDropdown === item.name }"
          @click="toggleDropdown(item.name)"
        >
          <SaturnIcon v-if="item.icon === 'saturn'" class="size-4" />
          <span v-else class="size-4" :class="[item.icon]" />
          <span>{{ item.label }}</span>
          <span
            class="i-lucide-chevron-down size-3 transition-transform"
            :class="{ 'rotate-180': activeDropdown === item.name }"
          />
        </button>

        <!-- Dropdown -->
        <Transition
          enter-active-class="transition ease-out duration-100"
          enter-from-class="transform opacity-0 scale-95"
          enter-to-class="transform opacity-100 scale-100"
          leave-active-class="transition ease-in duration-75"
          leave-from-class="transform opacity-100 scale-100"
          leave-to-class="transform opacity-0 scale-95"
        >
          <div
            v-if="activeDropdown === item.name && item.children?.length"
            class="absolute top-full left-0 mt-1 w-56 bg-n-solid-2 border border-n-weak rounded-xl shadow-lg py-1 z-50"
          >
            <button
              v-for="child in item.children"
              :key="child.name"
              class="w-full text-left px-4 py-2.5 text-sm hover:bg-n-alpha-2 transition-colors flex items-center gap-2"
              :class="{
                'bg-n-alpha-1 text-n-blue-text': isActiveRoute(
                  child.to?.name,
                  child.activeOn
                ),
              }"
              @click="navigateTo(child.to)"
            >
              {{ child.label }}
            </button>
          </div>
        </Transition>
      </div>
    </nav>

    <!-- Right: Settings & Profile -->
    <div class="flex items-center gap-2">
      <!-- Settings Dropdown -->
      <div class="relative">
        <button
          class="flex items-center gap-2 px-3 py-2 rounded-lg text-sm font-medium transition-colors hover:bg-n-alpha-2"
          :class="{ 'bg-n-alpha-2': settingsOpen }"
          @click="toggleSettings"
        >
          <span class="i-lucide-settings size-4" />
          <span>{{ t('SIDEBAR.SETTINGS') }}</span>
          <span
            class="i-lucide-chevron-down size-3 transition-transform"
            :class="{ 'rotate-180': settingsOpen }"
          />
        </button>

        <Transition
          enter-active-class="transition ease-out duration-100"
          enter-from-class="transform opacity-0 scale-95"
          enter-to-class="transform opacity-100 scale-100"
          leave-active-class="transition ease-in duration-75"
          leave-from-class="transform opacity-100 scale-100"
          leave-to-class="transform opacity-0 scale-95"
        >
          <div
            v-if="settingsOpen"
            class="absolute top-full right-0 mt-1 w-56 bg-n-solid-2 border border-n-weak rounded-xl shadow-lg py-1 z-50"
          >
            <button
              v-for="item in settingsItems"
              :key="item.name"
              class="w-full text-left px-4 py-2.5 text-sm hover:bg-n-alpha-2 transition-colors flex items-center gap-2"
              @click="navigateTo(item.to)"
            >
              <span class="size-4" :class="[item.icon]" />
              {{ item.label }}
            </button>
          </div>
        </Transition>
      </div>

      <!-- Subscription Button -->
      <button
        class="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium transition-colors bg-n-blue-3/50 hover:bg-n-blue-3 text-n-blue-11 border border-n-blue-6/30"
        @click="goToSubscriptionPage"
      >
        <span>Plan:</span>
        <span class="font-semibold">{{ subscriptionPlanName }}</span>
      </button>

      <!-- Profile Dropdown -->
      <div class="relative">
        <button
          class="flex items-center gap-2 px-2 py-1.5 rounded-lg transition-colors hover:bg-n-alpha-2"
          :class="{ 'bg-n-alpha-2': profileOpen }"
          @click="toggleProfile"
        >
          <Avatar
            :size="32"
            :name="userName"
            :src="userAvatar"
            :status="currentUserAvailability"
            class="flex-shrink-0"
            rounded-full
          />
          <span
            class="i-lucide-chevron-down size-3 transition-transform"
            :class="{ 'rotate-180': profileOpen }"
          />
        </button>

        <Transition
          enter-active-class="transition ease-out duration-100"
          enter-from-class="transform opacity-0 scale-95"
          enter-to-class="transform opacity-100 scale-100"
          leave-active-class="transition ease-in duration-75"
          leave-from-class="transform opacity-100 scale-100"
          leave-to-class="transform opacity-0 scale-95"
        >
          <div
            v-if="profileOpen"
            class="absolute top-full right-0 mt-1 w-72 bg-n-solid-2 border border-n-weak rounded-xl shadow-lg py-2 z-50"
          >
            <!-- User Info -->
            <div class="px-4 py-2 border-b border-n-weak">
              <button
                v-if="currentSubscription?.plan"
                class="text-xs font-semibold text-n-iris-11 hover:text-n-iris-12 cursor-pointer transition-colors mb-1"
                @click="goToSubscriptionPage"
              >
                {{ currentSubscription.plan.name }}
              </button>
              <p class="font-medium text-sm">{{ userName }}</p>
              <p class="text-xs text-n-slate-11">{{ userEmail }}</p>
            </div>

            <!-- Availability Status -->
            <div class="px-4 py-2 border-b border-n-weak">
              <p class="text-xs text-n-slate-11 mb-2">
                {{ t('PROFILE_SETTINGS.FORM.AVAILABILITY.LABEL') }}
              </p>
              <div class="flex gap-1">
                <button
                  v-for="status in availabilityStatuses"
                  :key="status.value"
                  class="flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-xs font-medium transition-colors"
                  :class="
                    currentUserAvailability === status.value
                      ? 'bg-n-alpha-3'
                      : 'hover:bg-n-alpha-1'
                  "
                  @click="setAvailability(status.value)"
                >
                  <span class="size-2 rounded-full" :class="[status.color]" />
                  {{ t(status.label) }}
                </button>
              </div>
            </div>

            <!-- Menu Items -->
            <button
              class="w-full text-left px-4 py-2.5 text-sm hover:bg-n-alpha-2 transition-colors flex items-center gap-2"
              @click="goToProfileSettings"
            >
              <span class="i-lucide-user-pen size-4" />
              {{ t('SIDEBAR_ITEMS.PROFILE_SETTINGS') }}
            </button>
            <button
              class="w-full text-left px-4 py-2.5 text-sm hover:bg-n-alpha-2 transition-colors flex items-center gap-2"
              @click="openAppearanceSettings"
            >
              <span class="i-lucide-palette size-4" />
              {{ t('SIDEBAR_ITEMS.APPEARANCE') }}
            </button>
            <button
              v-if="isSuperAdmin"
              class="w-full text-left px-4 py-2.5 text-sm hover:bg-n-alpha-2 transition-colors flex items-center gap-2"
              @click="openSuperAdmin"
            >
              <span class="i-lucide-castle size-4" />
              {{ t('SIDEBAR_ITEMS.SUPER_ADMIN_CONSOLE') }}
            </button>
            <div class="border-t border-n-weak mt-1 pt-1">
              <button
                class="w-full text-left px-4 py-2.5 text-sm hover:bg-n-alpha-2 transition-colors flex items-center gap-2 text-n-ruby-11"
                @click="logout"
              >
                <span class="i-lucide-power size-4" />
                {{ t('SIDEBAR_ITEMS.LOGOUT') }}
              </button>
            </div>
          </div>
        </Transition>
      </div>
    </div>
  </header>
</template>

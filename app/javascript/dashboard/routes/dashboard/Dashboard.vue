<script>
import { defineAsyncComponent, ref } from 'vue';

import NextHeader from 'next/header/Header.vue';
import WootKeyShortcutModal from 'dashboard/components/widgets/modal/WootKeyShortcutModal.vue';
import AddAccountModal from 'dashboard/components/app/AddAccountModal.vue';
import UpgradePage from 'dashboard/routes/dashboard/upgrade/UpgradePage.vue';

import { useUISettings } from 'dashboard/composables/useUISettings';
import { useAccount } from 'dashboard/composables/useAccount';
import { useWindowSize } from '@vueuse/core';

import wootConstants from 'dashboard/constants/globals';

const CommandBar = defineAsyncComponent(
  () => import('./commands/commandbar.vue')
);

import CopilotLauncher from 'dashboard/components-next/copilot/CopilotLauncher.vue';
import CopilotContainer from 'dashboard/components/copilot/CopilotContainer.vue';

export default {
  components: {
    NextHeader,
    CommandBar,
    WootKeyShortcutModal,
    AddAccountModal,
    UpgradePage,
    CopilotLauncher,
    CopilotContainer,
  },
  setup() {
    const upgradePageRef = ref(null);
    const { uiSettings, updateUISettings } = useUISettings();
    const { accountId } = useAccount();
    const { width: windowWidth } = useWindowSize();

    return {
      uiSettings,
      updateUISettings,
      accountId,
      upgradePageRef,
      windowWidth,
    };
  },
  data() {
    return {
      showAccountModal: false,
      showCreateAccountModal: false,
      showShortcutModal: false,
    };
  },
  computed: {
    isSmallScreen() {
      return this.windowWidth < wootConstants.SMALL_SCREEN_BREAKPOINT;
    },
    showUpgradePage() {
      return this.upgradePageRef?.shouldShowUpgradePage;
    },
    bypassUpgradePage() {
      return [
        'billing_settings_index',
        'settings_inbox_list',
        'general_settings_index',
        'agent_list',
      ].includes(this.$route.name);
    },
    previouslyUsedDisplayType() {
      const {
        previously_used_conversation_display_type: conversationDisplayType,
      } = this.uiSettings;
      return conversationDisplayType;
    },
  },
  watch: {
    isSmallScreen: {
      handler() {
        const { LAYOUT_TYPES } = wootConstants;
        if (window.innerWidth <= wootConstants.SMALL_SCREEN_BREAKPOINT) {
          this.updateUISettings({
            conversation_display_type: LAYOUT_TYPES.EXPANDED,
          });
        } else {
          this.updateUISettings({
            conversation_display_type: this.previouslyUsedDisplayType,
          });
        }
      },
      immediate: true,
    },
  },
  methods: {
    openCreateAccountModal() {
      this.showAccountModal = false;
      this.showCreateAccountModal = true;
    },
    closeCreateAccountModal() {
      this.showCreateAccountModal = false;
    },
    toggleAccountModal() {
      this.showAccountModal = !this.showAccountModal;
    },
    toggleKeyShortcutModal() {
      this.showShortcutModal = true;
    },
    closeKeyShortcutModal() {
      this.showShortcutModal = false;
    },
  },
};
</script>

<template>
  <div class="flex flex-col flex-grow overflow-hidden text-n-slate-12 h-screen">
    <NextHeader
      @toggle-account-modal="toggleAccountModal"
      @open-key-shortcut-modal="toggleKeyShortcutModal"
      @close-key-shortcut-modal="closeKeyShortcutModal"
      @show-create-account-modal="openCreateAccountModal"
    />

    <main class="flex flex-1 h-full w-full min-h-0 px-0 overflow-hidden">
      <UpgradePage
        v-show="showUpgradePage"
        ref="upgradePageRef"
        :bypass-upgrade-page="bypassUpgradePage"
      />
      <template v-if="!showUpgradePage">
        <router-view />
        <CommandBar />
        <CopilotLauncher />
        <CopilotContainer />
      </template>
      <AddAccountModal
        :show="showCreateAccountModal"
        @close-account-create-modal="closeCreateAccountModal"
      />
      <WootKeyShortcutModal
        v-model:show="showShortcutModal"
        @close="closeKeyShortcutModal"
        @clickaway="closeKeyShortcutModal"
      />
    </main>
  </div>
</template>

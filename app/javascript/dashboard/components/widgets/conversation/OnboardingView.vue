<script setup>
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { useStoreGetters } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';

const router = useRouter();
const getters = useStoreGetters();
const { accountId } = useAccount();

const currentUser = computed(() => getters.getCurrentUser.value);

const navigateToInbox = () => {
  router.push({
    name: 'settings_inbox_new',
    params: { accountId: accountId.value },
  });
};
</script>

<template>
  <div
    class="min-h-screen flex items-center justify-center p-8 bg-n-slate-1"
  >
    <div
      class="max-w-xl w-full text-center space-y-8"
    >
      <!-- Icon -->
      <div class="flex justify-center">
        <div
          class="w-24 h-24 rounded-2xl bg-n-brand flex items-center justify-center shadow-lg"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="w-12 h-12 text-white"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            stroke-width="1.5"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M8.625 12a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H8.25m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H12m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0h-.375M21 12c0 4.556-4.03 8.25-9 8.25a9.764 9.764 0 01-2.555-.337A5.972 5.972 0 015.41 20.97a5.969 5.969 0 01-.474-.065 4.48 4.48 0 00.978-2.025c.09-.457-.133-.901-.467-1.226C3.93 16.178 3 14.189 3 12c0-4.556 4.03-8.25 9-8.25s9 3.694 9 8.25z"
            />
          </svg>
        </div>
      </div>

      <!-- Welcome Text -->
      <div class="space-y-3">
        <h1
          class="text-3xl font-bold text-n-slate-12 font-interDisplay tracking-tight"
        >
          {{ $t('ONBOARDING.EMPTY_STATE.TITLE', { name: currentUser.name }) }}
        </h1>
        <p class="text-n-slate-11 text-lg leading-relaxed max-w-md mx-auto">
          {{ $t('ONBOARDING.EMPTY_STATE.DESCRIPTION') }}
        </p>
      </div>

      <!-- Channel Info Card -->
      <div
        class="bg-white/60 dark:bg-n-slate-3/60 backdrop-blur-sm border border-n-slate-4 rounded-2xl p-6 space-y-4"
      >
        <!-- eslint-disable vue/no-bare-strings-in-template -->
        <div class="flex items-center justify-center gap-4 flex-wrap">
          <div
            class="flex items-center gap-2 px-3 py-1.5 bg-n-slate-2 rounded-lg text-sm text-n-slate-11"
          >
            <i class="i-ri-whatsapp-fill text-lg text-green-500" />
            <span>WhatsApp</span>
          </div>
          <div
            class="flex items-center gap-2 px-3 py-1.5 bg-n-slate-2 rounded-lg text-sm text-n-slate-11"
          >
            <i class="i-ri-mail-fill text-lg text-n-blue-9" />
            <span>Email</span>
          </div>
          <div
            class="flex items-center gap-2 px-3 py-1.5 bg-n-slate-2 rounded-lg text-sm text-n-slate-11"
          >
            <i class="i-ri-global-fill text-lg text-n-slate-9" />
            <span>Web Chat</span>
          </div>
          <div
            class="flex items-center gap-2 px-3 py-1.5 bg-n-slate-2 rounded-lg text-sm text-n-slate-11"
          >
            <i class="i-ri-instagram-fill text-lg text-pink-500" />
            <span>Instagram</span>
          </div>
        </div>
        <!-- eslint-enable vue/no-bare-strings-in-template -->
        <p class="text-n-slate-10 text-sm">
          {{ $t('ONBOARDING.EMPTY_STATE.CHANNELS_INFO') }}
        </p>
      </div>

      <!-- CTA Button -->
      <button
        class="inline-flex items-center gap-2 px-8 py-4 bg-n-brand hover:bg-n-brand/90 text-white font-semibold rounded-xl shadow-lg hover:shadow-xl transition-all duration-200"
        @click="navigateToInbox"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="w-5 h-5"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          stroke-width="2"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M12 4.5v15m7.5-7.5h-15"
          />
        </svg>
        {{ $t('ONBOARDING.EMPTY_STATE.ADD_CHANNEL') }}
      </button>

      <!-- Help Text -->
      <p class="text-n-slate-10 text-sm">
        {{ $t('ONBOARDING.EMPTY_STATE.HELP_TEXT') }}
      </p>
    </div>
  </div>
</template>

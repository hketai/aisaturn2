<script setup>
import { computed } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';

const accountId = useMapGetter('getCurrentAccountId');
const isFeatureEnabled = useMapGetter('accounts/isFeatureEnabledonAccount');

const showBanner = computed(() => {
  return isFeatureEnabled.value(accountId.value, 'saturn_integration');
});
</script>

<template>
  <div
    v-if="showBanner"
    class="flex items-center justify-between p-4 mb-5 rounded-lg bg-n-alpha-2 border border-n-weak"
  >
    <div class="flex items-center gap-3">
      <div class="flex-shrink-0">
        <svg
          width="20"
          height="20"
          viewBox="0 0 20 20"
          fill="none"
          class="text-n-slate-11"
        >
          <path
            d="M10 2L2 7L10 12L18 7L10 2Z"
            stroke="currentColor"
            stroke-width="1.5"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
          <path
            d="M2 13L10 18L18 13"
            stroke="currentColor"
            stroke-width="1.5"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
          <path
            d="M2 10L10 15L18 10"
            stroke="currentColor"
            stroke-width="1.5"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
        </svg>
      </div>
      <div>
        <p class="text-sm font-medium text-n-slate-12">
          {{ $t('SATURN.USAGE_BANNER.TITLE') }}
        </p>
        <p class="text-xs text-n-slate-11">
          {{ $t('SATURN.USAGE_BANNER.DESCRIPTION') }}
        </p>
      </div>
    </div>
  </div>
</template>

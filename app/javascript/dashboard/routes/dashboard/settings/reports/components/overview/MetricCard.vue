<script setup>
import Spinner from 'shared/components/Spinner.vue';

defineProps({
  header: {
    type: String,
    default: '',
  },
  isLoading: {
    type: Boolean,
    default: false,
  },
  loadingMessage: {
    type: String,
    default: '',
  },
  icon: {
    type: String,
    default: '',
  },
});
</script>

<template>
  <div
    class="flex flex-col bg-n-slate-1 border border-n-slate-4 rounded-xl overflow-hidden h-full"
  >
    <!-- Card Header -->
    <div
      class="flex items-center justify-between px-5 py-4 border-b border-n-slate-4 bg-n-slate-2/50"
    >
      <slot name="header">
        <div class="flex items-center gap-3">
          <div
            v-if="icon"
            class="w-9 h-9 rounded-lg bg-n-brand/10 flex items-center justify-center"
          >
            <i :class="icon" class="text-lg text-n-brand" />
          </div>
          <div class="flex items-center gap-2">
            <h3 class="text-base font-medium text-n-slate-12">
              {{ header }}
            </h3>
            <span
              class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-n-teal-3 text-xs"
            >
              <span class="w-1.5 h-1.5 rounded-full bg-n-teal-9 animate-pulse" />
              <span class="text-n-teal-11 font-medium">
                {{ $t('OVERVIEW_REPORTS.LIVE') }}
              </span>
            </span>
          </div>
        </div>
      </slot>
      <div class="flex items-center gap-2">
        <slot name="control" />
      </div>
    </div>

    <!-- Card Body -->
    <div class="flex-1 p-5">
      <div
        v-if="!isLoading"
        class="flex flex-wrap gap-6"
      >
        <slot />
      </div>
      <div
        v-else
        class="flex items-center justify-center gap-3 py-8"
      >
        <Spinner size="small" />
        <span class="text-sm text-n-slate-11">
          {{ loadingMessage }}
        </span>
      </div>
    </div>
  </div>
</template>

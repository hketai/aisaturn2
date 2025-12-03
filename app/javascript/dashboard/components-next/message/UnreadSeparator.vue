<script setup>
import { useI18n } from 'vue-i18n';

defineProps({
  count: {
    type: Number,
    default: 0,
  },
});

const { t } = useI18n();
</script>

<template>
  <div class="flex items-center my-3 px-4">
    <div class="flex-1 h-px bg-n-teal-7/50" />
    <span
      class="px-3 py-1 mx-2 text-xs font-medium rounded-full bg-n-teal-9/20 text-n-teal-11 whitespace-nowrap"
    >
      {{ count }} {{ t('CONVERSATION.UNREAD_MESSAGES') }}
    </span>
    <div class="flex-1 h-px bg-n-teal-7/50" />
  </div>
</template>


<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import isToday from 'date-fns/isToday';
import isYesterday from 'date-fns/isYesterday';
import format from 'date-fns/format';

const props = defineProps({
  date: {
    type: [String, Number, Date],
    required: true,
  },
});

const { t } = useI18n();

const displayDate = computed(() => {
  const dateValue = new Date(props.date);

  if (isToday(dateValue)) {
    return t('CONVERSATION.DATE.TODAY');
  }

  if (isYesterday(dateValue)) {
    return t('CONVERSATION.DATE.YESTERDAY');
  }

  return format(dateValue, 'd MMMM yyyy');
});
</script>

<template>
  <div class="flex justify-center my-4">
    <span
      class="px-3 py-1 text-xs font-medium rounded-lg bg-n-slate-3/80 text-n-slate-11 shadow-sm"
    >
      {{ displayDate }}
    </span>
  </div>
</template>


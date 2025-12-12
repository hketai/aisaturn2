<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';

import PageHeader from '../SettingsSubPageHeader.vue';

const { t } = useI18n();
const route = useRoute();

const isFirstStep = computed(() => {
  return route.name === 'settings_inbox_new';
});

const isFinishStep = computed(() => {
  return route.name === 'settings_inbox_finish';
});

const pageTitle = computed(() => {
  if (isFirstStep.value) {
    return t('INBOX_MGMT.ADD.AUTH.TITLE');
  }
  if (isFinishStep.value) {
    return t('INBOX_MGMT.ADD.AUTH.TITLE_FINISH');
  }
  return t('INBOX_MGMT.ADD.AUTH.TITLE_NEXT');
});
</script>

<template>
  <div class="mx-2 flex flex-col gap-6 mb-8 px-5 flex-1 overflow-hidden">
    <PageHeader class="!mb-0" :header-title="pageTitle" />
    <div
      class="rounded-xl border border-n-weak min-h-[52rem] overflow-hidden"
    >
      <router-view />
    </div>
  </div>
</template>

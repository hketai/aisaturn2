<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import SaturnPageLayout from 'dashboard/components-next/saturn/SaturnPageLayout.vue';
import saturnAssistantAPI from 'dashboard/api/saturn/assistant';

const route = useRoute();
const assistantId = Number(route.params.assistantId);
const assistant = ref(null);
const isFetching = ref(false);

const fetchAssistant = async () => {
  isFetching.value = true;
  try {
    const response = await saturnAssistantAPI.show(assistantId);
    assistant.value = response.data;
  } catch (error) {
    console.error('Error fetching assistant:', error);
    useAlert('Asistan bilgileri yüklenemedi');
  } finally {
    isFetching.value = false;
  }
};

onMounted(() => {
  fetchAssistant();
});
</script>

<template>
  <SaturnPageLayout
    :page-title="
      assistant?.name
        ? `${assistant.name} - ${$t('SATURN.ASSISTANTS.OPTIONS.HANDOFF_SETTINGS')}`
        : $t('SATURN.ASSISTANTS.OPTIONS.HANDOFF_SETTINGS')
    "
    :action-permissions="['administrator']"
    :enable-pagination="false"
    :is-loading="isFetching"
    :has-no-data="false"
    :total-records="0"
    :feature-flag-key="FEATURE_FLAGS.SATURN"
    :return-path="{ name: 'saturn_assistants_edit', params: { assistantId } }"
  >
    <template #contentArea>
      <div
        class="flex flex-col gap-4 p-6 bg-n-slate-1 rounded-lg border border-n-slate-4"
      >
        <p class="text-sm text-n-slate-11">
          {{ $t('SATURN.ASSISTANTS.HANDOFF.DESCRIPTION') }}
        </p>
        <p class="text-sm text-n-slate-11 italic">
          Bu özellik yakında eklenecektir.
        </p>
      </div>
    </template>
  </SaturnPageLayout>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import SaturnPageLayout from 'dashboard/components-next/saturn/SaturnPageLayout.vue';
import SaturnAssistantForm from '../../../../components-next/saturn/pageComponents/assistant/SaturnAssistantForm.vue';
import SaturnTestInterface from '../../../../components-next/saturn/assistant/SaturnTestInterface.vue';
import saturnAssistantAPI from 'dashboard/api/saturn/assistant';

const route = useRoute();
const router = useRouter();
const { t } = useI18n();
const assistantId = Number(route.params.assistantId);
const assistant = ref(null);
const isFetching = ref(true);
const isSubmitting = ref(false);

const isAssistantAvailable = computed(() => !!assistant.value?.id);

const handleSubmit = async updatedAssistant => {
  try {
    isSubmitting.value = true;
    await saturnAssistantAPI.update({
      id: assistantId,
      ...updatedAssistant,
    });
    useAlert(t('SATURN.ASSISTANTS.MODIFY.SUCCESS_MESSAGE'));
    // Reload assistant data
    await fetchAssistant();
  } catch (error) {
    const errorMessage =
      error?.response?.data?.error ||
      error?.message ||
      t('SATURN.ASSISTANTS.MODIFY.ERROR_MESSAGE');
    useAlert(errorMessage);
  } finally {
    isSubmitting.value = false;
  }
};

const fetchAssistant = async () => {
  isFetching.value = true;
  try {
    const response = await saturnAssistantAPI.show(assistantId);
    assistant.value = response.data;
  } catch (error) {
    console.error('Error fetching Saturn assistant:', error);
    assistant.value = null;
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
    :page-title="assistant?.name || $t('SATURN.ASSISTANTS.EDIT.HEADER')"
    :is-loading="isFetching"
    :feature-flag-key="FEATURE_FLAGS.SATURN"
    :return-path="{ name: 'saturn_assistants_index' }"
  >
    <template #contentArea>
      <div
        v-if="!isFetching && !isAssistantAvailable"
        class="text-center py-12"
      >
        <p class="text-lg text-gray-600">
          {{ $t('SATURN.ASSISTANTS.EDIT.NOT_FOUND') }}
        </p>
      </div>
      <div
        v-else-if="isAssistantAvailable"
        class="flex flex-col lg:flex-row gap-6 h-full"
      >
        <div class="flex-1 lg:overflow-auto pr-0 lg:pr-4">
          <SaturnAssistantForm
            form-mode="modify"
            :assistant-data="assistant"
            :is-submitting="isSubmitting"
            @submit="handleSubmit"
          />
        </div>
        <div class="w-full lg:w-[400px] h-[600px] lg:h-full flex-shrink-0">
          <SaturnTestInterface :assistant-id="assistantId" />
        </div>
      </div>
    </template>
  </SaturnPageLayout>
</template>

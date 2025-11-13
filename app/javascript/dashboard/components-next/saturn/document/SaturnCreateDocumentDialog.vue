<script setup>
import { ref } from 'vue';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import saturnDocumentAPI from 'dashboard/api/saturn/document';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import SaturnDocumentForm from './SaturnDocumentForm.vue';

const props = defineProps({
  assistants: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['close']);

const { t } = useI18n();

const dialogRef = ref(null);
const formRef = ref(null);
const isSubmitting = ref(false);

const handleFormSubmit = async formData => {
  try {
    isSubmitting.value = true;
    const assistantId = formData.get('document[assistant_id]');
    await saturnDocumentAPI.create({
      assistantId,
      document: formData,
    });
    useAlert(t('SATURN.DOCUMENTS.CREATE.SUCCESS_MESSAGE'));
    dialogRef.value.close();
    emit('close');
  } catch (error) {
    const errorMessage =
      error?.response?.data?.error ||
      error?.message ||
      t('SATURN.DOCUMENTS.CREATE.ERROR_MESSAGE');
    useAlert(errorMessage);
  } finally {
    isSubmitting.value = false;
  }
};

const handleDialogClose = () => {
  emit('close');
};

const handleCancelAction = () => {
  dialogRef.value.close();
};

defineExpose({ dialogRef });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="$t('SATURN.DOCUMENTS.CREATE.TITLE')"
    :description="$t('SATURN.DOCUMENTS.FORM_DESCRIPTION')"
    :show-cancel-button="false"
    :show-confirm-button="false"
    @close="handleDialogClose"
  >
    <SaturnDocumentForm
      ref="formRef"
      :assistants="assistants"
      :is-submitting="isSubmitting"
      @submit="handleFormSubmit"
      @cancel="handleCancelAction"
    />
    <template #footer />
  </Dialog>
</template>

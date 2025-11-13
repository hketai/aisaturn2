<script setup>
import { ref, computed } from 'vue';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import saturnAssistantAPI from 'dashboard/api/saturn/assistant';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import SaturnAssistantForm from './SaturnAssistantForm.vue';

const props = defineProps({
  existingAssistant: {
    type: Object,
    default: () => ({}),
  },
  dialogMode: {
    type: String,
    default: 'create',
    validator: value => ['create', 'modify'].includes(value),
  },
});
const emit = defineEmits(['dialogClosed']);
const { t } = useI18n();

const dialogRef = ref(null);
const formRef = ref(null);
const isSubmitting = ref(false);

const translationKey = computed(
  () => `SATURN.ASSISTANTS.${props.dialogMode.toUpperCase()}`
);

const handleFormSubmit = async assistantData => {
  try {
    isSubmitting.value = true;
    if (props.dialogMode === 'modify') {
      await saturnAssistantAPI.update({
        id: props.existingAssistant.id,
        ...assistantData,
      });
    } else {
      await saturnAssistantAPI.create(assistantData);
    }
    useAlert(t(`${translationKey.value}.SUCCESS_MESSAGE`));
    dialogRef.value.close();
    emit('dialogClosed');
  } catch (error) {
    const errorMessage =
      error?.response?.data?.error ||
      error?.message ||
      t(`${translationKey.value}.ERROR_MESSAGE`);
    useAlert(errorMessage);
  } finally {
    isSubmitting.value = false;
  }
};

const handleDialogClose = () => {
  emit('dialogClosed');
};

const handleCancelAction = () => {
  dialogRef.value.close();
};

defineExpose({ dialogRef });
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="edit"
    :title="t(`${translationKey}.TITLE`)"
    :description="t('SATURN.ASSISTANTS.FORM_DESCRIPTION')"
    :show-cancel-button="false"
    :show-confirm-button="false"
    overflow-y-auto
    class="saturn-dialog"
    @close="handleDialogClose"
  >
    <div class="saturn-dialog-content">
      <SaturnAssistantForm
        ref="formRef"
        :form-mode="dialogMode"
        :assistant-data="existingAssistant"
        :is-submitting="isSubmitting"
        @submit="handleFormSubmit"
        @cancel="handleCancelAction"
      />
    </div>
    <template #footer />
  </Dialog>
</template>

<script setup>
import { ref, computed } from 'vue';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import saturnResponseAPI from 'dashboard/api/saturn/response';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import SaturnResponseForm from './SaturnResponseForm.vue';

const props = defineProps({
  assistants: {
    type: Array,
    default: () => [],
  },
  response: {
    type: Object,
    default: () => ({}),
  },
  dialogMode: {
    type: String,
    default: 'create',
    validator: value => ['create', 'edit'].includes(value),
  },
});

const emit = defineEmits(['close']);

const { t } = useI18n();

const dialogRef = ref(null);
const formRef = ref(null);
const isSubmitting = ref(false);

const translationKey = computed(
  () => `SATURN.RESPONSES.${props.dialogMode.toUpperCase()}`
);

const handleFormSubmit = async responseData => {
  try {
    isSubmitting.value = true;
    if (props.dialogMode === 'edit') {
      await saturnResponseAPI.update(props.response.id, responseData);
    } else {
      await saturnResponseAPI.create({
        assistantId: responseData.assistant_id,
        ...responseData,
      });
    }
    useAlert(t(`${translationKey.value}.SUCCESS_MESSAGE`));
    dialogRef.value.close();
    emit('close');
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
    :title="$t(`${translationKey}.TITLE`)"
    :description="$t('SATURN.RESPONSES.FORM_DESCRIPTION')"
    :show-cancel-button="false"
    :show-confirm-button="false"
    @close="handleDialogClose"
  >
    <SaturnResponseForm
      ref="formRef"
      :assistants="assistants"
      :response="response"
      :is-submitting="isSubmitting"
      @submit="handleFormSubmit"
      @cancel="handleCancelAction"
    />
    <template #footer />
  </Dialog>
</template>

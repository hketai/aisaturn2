<script setup>
import { ref } from 'vue';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import saturnInboxesAPI from 'dashboard/api/saturn/inboxes';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import SaturnConnectInboxForm from './SaturnConnectInboxForm.vue';

const props = defineProps({
  assistantId: {
    type: Number,
    required: true,
  },
});

const emit = defineEmits(['close']);

const { t } = useI18n();

const dialogRef = ref(null);
const connectForm = ref(null);

const handleSubmit = async payload => {
  try {
    await saturnInboxesAPI.create(payload);
    useAlert(t('SATURN.INBOXES.CREATE.SUCCESS_MESSAGE'));
    dialogRef.value.close();
    emit('close');
  } catch (error) {
    const errorMessage =
      error?.response?.data?.error ||
      error?.message ||
      t('SATURN.INBOXES.CREATE.ERROR_MESSAGE');
    useAlert(errorMessage);
  }
};

const handleClose = () => {
  emit('close');
};

const handleCancel = () => {
  dialogRef.value.close();
};

defineExpose({ dialogRef });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="$t('SATURN.INBOXES.CREATE.TITLE')"
    :description="$t('SATURN.INBOXES.FORM_DESCRIPTION')"
    :show-cancel-button="false"
    :show-confirm-button="false"
    @close="handleClose"
  >
    <SaturnConnectInboxForm
      ref="connectForm"
      :assistant-id="assistantId"
      @submit="handleSubmit"
      @cancel="handleCancel"
    />
    <template #footer />
  </Dialog>
</template>

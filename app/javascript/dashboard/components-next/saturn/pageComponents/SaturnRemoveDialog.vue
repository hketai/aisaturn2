<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import saturnAssistantAPI from 'dashboard/api/saturn/assistant';
import saturnDocumentAPI from 'dashboard/api/saturn/document';
import saturnResponseAPI from 'dashboard/api/saturn/response';
import saturnScenariosAPI from 'dashboard/api/saturn/scenarios';
import saturnToolsAPI from 'dashboard/api/saturn/customTools';
import saturnInboxesAPI from 'dashboard/api/saturn/inboxes';

const props = defineProps({
  entityType: {
    type: String,
    required: true,
  },
  i18nPrefix: {
    type: String,
    required: true,
  },
  targetEntity: {
    type: Object,
    required: true,
  },
  deletePayload: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits(['deleteSuccess']);

const { t } = useI18n();
const dialogRef = ref(null);
const translationKey = computed(() => {
  return props.i18nPrefix || props.entityType.toUpperCase();
});

const getDeleteAPI = () => {
  const type = props.entityType.toLowerCase();
  if (type.includes('assistant')) return saturnAssistantAPI;
  if (type.includes('document')) return saturnDocumentAPI;
  if (type.includes('response')) return saturnResponseAPI;
  if (type.includes('scenario')) return saturnScenariosAPI;
  if (type.includes('tool')) return saturnToolsAPI;
  if (type.includes('inbox')) return saturnInboxesAPI;
  return null;
};

const performRemoval = async () => {
  const api = getDeleteAPI();
  if (!api) {
    useAlert('Delete API not found');
    return;
  }

  try {
    if (props.deletePayload) {
      if (props.entityType.includes('Inbox')) {
        await api.delete(props.deletePayload);
      } else if (props.entityType.includes('Document')) {
        await api.delete({
          assistantId: props.deletePayload.assistantId,
          id: props.targetEntity.id,
        });
      } else if (props.entityType.includes('Scenario')) {
        await api.delete({
          assistantId: props.deletePayload.assistantId,
          id: props.targetEntity.id,
        });
      } else {
        await api.delete(props.targetEntity.id);
      }
    } else {
      await api.delete(props.targetEntity.id);
    }
    emit('deleteSuccess');
    useAlert(t(`SATURN.${translationKey.value}.REMOVE.SUCCESS_MESSAGE`));
  } catch (error) {
    useAlert(
      error?.response?.data?.error ||
        t(`SATURN.${translationKey.value}.REMOVE.ERROR_MESSAGE`)
    );
  }
};

const handleConfirmRemoval = async () => {
  await performRemoval();
  dialogRef.value?.close();
};

defineExpose({ dialogRef });
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="alert"
    :title="t(`SATURN.${translationKey.value}.REMOVE.TITLE`)"
    :description="t(`SATURN.${translationKey.value}.REMOVE.DESCRIPTION`)"
    :confirm-button-label="t(`SATURN.${translationKey.value}.REMOVE.CONFIRM`)"
    @confirm="handleConfirmRemoval"
  />
</template>

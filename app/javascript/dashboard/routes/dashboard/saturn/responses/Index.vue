<script setup>
import { computed, onMounted, ref, nextTick } from 'vue';
import { useAlert } from 'dashboard/composables';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import SaturnPageLayout from 'dashboard/components-next/saturn/SaturnPageLayout.vue';
import SaturnResponseCard from 'dashboard/components-next/saturn/response/SaturnResponseCard.vue';
import SaturnRemoveDialog from 'dashboard/components-next/saturn/pageComponents/SaturnRemoveDialog.vue';
import SaturnCreateResponseDialog from 'dashboard/components-next/saturn/response/SaturnCreateResponseDialog.vue';
import SaturnResponseEmptyState from 'dashboard/components-next/saturn/response/SaturnResponseEmptyState.vue';
import saturnResponseAPI from 'dashboard/api/saturn/response';
import saturnAssistantAPI from 'dashboard/api/saturn/assistant';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';

const responses = ref([]);
const assistants = ref([]);
const isFetching = ref(false);
const selectedAssistant = ref('all');
const selectedStatus = ref('all');
const selectedResponse = ref(null);
const deleteResponseDialog = ref(null);
const createResponseDialog = ref(null);
const showCreateDialog = ref(false);
const dialogType = ref('create');

const isEmpty = computed(() => !responses.value.length);
const assistantOptions = computed(() => [
  { value: 'all', label: 'All Assistants' },
  ...assistants.value.map(a => ({ value: a.id, label: a.name })),
]);

const statusOptions = computed(() => [
  { value: 'all', label: 'All Status' },
  { value: 'pending', label: 'Pending' },
  { value: 'approved', label: 'Approved' },
]);

const filteredResponses = computed(() => {
  // Backend'de zaten filtreleme yapılıyor, burada sadece gösteriyoruz
  return responses.value;
});

const handleDelete = () => {
  deleteResponseDialog.value.dialogRef.open();
};

const handleCreate = () => {
  dialogType.value = 'create';
  showCreateDialog.value = true;
  nextTick(() => createResponseDialog.value.dialogRef.open());
};

const handleEdit = () => {
  dialogType.value = 'edit';
  showCreateDialog.value = true;
  nextTick(() => createResponseDialog.value.dialogRef.open());
};

const handleAction = ({ action, id }) => {
  selectedResponse.value = responses.value.find(r => id === r.id);
  nextTick(() => {
    if (action === 'delete') {
      handleDelete();
    } else if (action === 'edit') {
      handleEdit();
    } else if (action === 'approve') {
      handleApprove();
    }
  });
};

const handleApprove = async () => {
  try {
    await saturnResponseAPI.update(selectedResponse.value.id, {
      status: 'approved',
    });
    useAlert('Response approved successfully');
    fetchResponses();
  } catch (error) {
    useAlert(error?.message || 'Failed to approve response');
  }
};

const handleCreateClose = () => {
  showCreateDialog.value = false;
  selectedResponse.value = null;
  fetchResponses();
};

const handleAssistantChange = assistantId => {
  selectedAssistant.value = assistantId;
  fetchResponses();
};

const handleStatusChange = status => {
  selectedStatus.value = status;
  fetchResponses();
};

const fetchAssistants = async () => {
  try {
    const response = await saturnAssistantAPI.get();
    assistants.value = Array.isArray(response.data) ? response.data : [];
  } catch (error) {
    console.error('Error fetching assistants:', error);
  }
};

const fetchResponses = async () => {
  isFetching.value = true;
  try {
    const params = {
      page: 1,
    };

    if (selectedAssistant.value !== 'all' && selectedAssistant.value) {
      params.assistantId = selectedAssistant.value;
    }

    if (selectedStatus.value !== 'all') {
      params.status = selectedStatus.value;
    }

    const response = await saturnResponseAPI.get(params);
    responses.value = Array.isArray(response.data) ? response.data : [];
  } catch (error) {
    console.error('Error fetching responses:', error);
    responses.value = [];
  } finally {
    isFetching.value = false;
  }
};

const onDeleteSuccess = () => {
  fetchResponses();
};

onMounted(() => {
  fetchAssistants();
  fetchResponses();
});
</script>

<template>
  <SaturnPageLayout
    :page-title="$t('SATURN.RESPONSES.HEADER')"
    :action-button-text="$t('SATURN.RESPONSES.ADD_NEW')"
    :action-permissions="['administrator']"
    :enable-pagination="false"
    :is-loading="isFetching"
    :has-no-data="isEmpty"
    :total-records="filteredResponses.length"
    :feature-flag-key="FEATURE_FLAGS.SATURN"
    @action="handleCreate"
  >
    <template #emptyStateSection>
      <SaturnResponseEmptyState @click="handleCreate" />
    </template>

    <template #topControls>
      <div v-if="assistants.length > 0" class="mb-4 flex gap-4">
        <ComboBox
          v-model="selectedAssistant"
          :options="assistantOptions"
          :placeholder="$t('SATURN.RESPONSES.SELECT_ASSISTANT')"
          @update:model-value="handleAssistantChange"
        />
        <ComboBox
          v-model="selectedStatus"
          :options="statusOptions"
          :placeholder="$t('SATURN.RESPONSES.SELECT_STATUS')"
          @update:model-value="handleStatusChange"
        />
      </div>
    </template>

    <template #contentArea>
      <div class="flex flex-col gap-4">
        <SaturnResponseCard
          v-for="response in filteredResponses"
          :id="response.id"
          :key="response.id"
          :question="response.question"
          :answer="response.answer"
          :status="response.status"
          :assistant="response.assistant"
          :created-at="response.created_at"
          @action="handleAction"
        />
      </div>
    </template>

    <SaturnRemoveDialog
      v-if="selectedResponse"
      ref="deleteResponseDialog"
      :target-entity="selectedResponse"
      entity-type="Responses"
      i18n-prefix="RESPONSES"
      @delete-success="onDeleteSuccess"
    />

    <SaturnCreateResponseDialog
      v-if="showCreateDialog"
      ref="createResponseDialog"
      :assistants="assistants"
      :response="selectedResponse"
      :dialog-mode="dialogType"
      @close="handleCreateClose"
    />
  </SaturnPageLayout>
</template>

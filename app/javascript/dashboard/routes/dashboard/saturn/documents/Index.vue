<script setup>
import { computed, onMounted, ref, nextTick } from 'vue';
import { useAlert } from 'dashboard/composables';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import SaturnPageLayout from 'dashboard/components-next/saturn/SaturnPageLayout.vue';
import SaturnDocumentCard from 'dashboard/components-next/saturn/document/SaturnDocumentCard.vue';
import SaturnRemoveDialog from 'dashboard/components-next/saturn/pageComponents/SaturnRemoveDialog.vue';
import SaturnCreateDocumentDialog from 'dashboard/components-next/saturn/document/SaturnCreateDocumentDialog.vue';
import SaturnDocumentEmptyState from 'dashboard/components-next/saturn/document/SaturnDocumentEmptyState.vue';
import saturnDocumentAPI from 'dashboard/api/saturn/document';
import saturnAssistantAPI from 'dashboard/api/saturn/assistant';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';

const documents = ref([]);
const assistants = ref([]);
const isFetching = ref(false);
const selectedAssistant = ref('all');
const selectedDocument = ref(null);
const deleteDocumentDialog = ref(null);
const createDocumentDialog = ref(null);
const showCreateDialog = ref(false);

const isEmpty = computed(() => !documents.value.length);
const assistantOptions = computed(() => [
  { value: 'all', label: 'All Assistants' },
  ...assistants.value.map(a => ({ value: a.id, label: a.name })),
]);

const handleDelete = () => {
  deleteDocumentDialog.value.dialogRef.open();
};

const handleCreate = () => {
  showCreateDialog.value = true;
  nextTick(() => createDocumentDialog.value.dialogRef.open());
};

const handleAction = ({ action, id }) => {
  selectedDocument.value = documents.value.find(doc => id === doc.id);
  nextTick(() => {
    if (action === 'delete') {
      handleDelete();
    }
  });
};

const handleCreateClose = () => {
  showCreateDialog.value = false;
  fetchDocuments();
};

const handleAssistantChange = assistantId => {
  selectedAssistant.value = assistantId;
  fetchDocuments();
};

const fetchAssistants = async () => {
  try {
    const response = await saturnAssistantAPI.get();
    assistants.value = Array.isArray(response.data) ? response.data : [];
  } catch (error) {
    console.error('Error fetching assistants:', error);
  }
};

const fetchDocuments = async () => {
  isFetching.value = true;
  try {
    const params = {
      page: 1,
    };

    if (selectedAssistant.value !== 'all' && selectedAssistant.value) {
      params.assistantId = selectedAssistant.value;
    }

    const response = await saturnDocumentAPI.get(params);
    documents.value = Array.isArray(response.data) ? response.data : [];
  } catch (error) {
    console.error('Error fetching documents:', error);
    documents.value = [];
  } finally {
    isFetching.value = false;
  }
};

const onDeleteSuccess = () => {
  fetchDocuments();
};

onMounted(() => {
  fetchAssistants();
  fetchDocuments();
});
</script>

<template>
  <SaturnPageLayout
    :page-title="$t('SATURN.DOCUMENTS.HEADER')"
    :action-button-text="$t('SATURN.DOCUMENTS.ADD_NEW')"
    :action-permissions="['administrator']"
    :enable-pagination="false"
    :is-loading="isFetching"
    :has-no-data="isEmpty"
    :total-records="documents.length"
    :feature-flag-key="FEATURE_FLAGS.SATURN"
    @action="handleCreate"
  >
    <template #emptyStateSection>
      <SaturnDocumentEmptyState @click="handleCreate" />
    </template>

    <template #topControls>
      <div v-if="assistants.length > 0" class="mb-4">
        <ComboBox
          v-model="selectedAssistant"
          :options="assistantOptions"
          :placeholder="$t('SATURN.DOCUMENTS.SELECT_ASSISTANT')"
          @update:model-value="handleAssistantChange"
        />
      </div>
    </template>

    <template #contentArea>
      <div class="flex flex-col gap-4">
        <SaturnDocumentCard
          v-for="doc in documents"
          :id="doc.id"
          :key="doc.id"
          :name="doc.name || doc.external_link"
          :external-link="doc.external_link"
          :assistant="doc.assistant"
          :created-at="doc.created_at"
          @action="handleAction"
        />
      </div>
    </template>

    <SaturnRemoveDialog
      v-if="selectedDocument"
      ref="deleteDocumentDialog"
      :target-entity="selectedDocument"
      entity-type="Documents"
      i18n-prefix="DOCUMENTS"
      @delete-success="onDeleteSuccess"
    />

    <SaturnCreateDocumentDialog
      v-if="showCreateDialog"
      ref="createDocumentDialog"
      :assistants="assistants"
      @close="handleCreateClose"
    />
  </SaturnPageLayout>
</template>

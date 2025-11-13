<script setup>
import { computed, onMounted, ref, nextTick } from 'vue';
import { useRouter } from 'vue-router';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

import SaturnPageLayout from 'dashboard/components-next/saturn/SaturnPageLayout.vue';
import SaturnAssistantItem from 'dashboard/components-next/saturn/assistant/SaturnAssistantItem.vue';
import SaturnRemoveDialog from 'dashboard/components-next/saturn/pageComponents/SaturnRemoveDialog.vue';
import SaturnCreateDialog from 'dashboard/components-next/saturn/pageComponents/assistant/SaturnCreateDialog.vue';
import SaturnAssistantPageEmptyState from 'dashboard/components-next/saturn/pageComponents/assistant/SaturnAssistantPageEmptyState.vue';
import saturnAssistantAPI from 'dashboard/api/saturn/assistant';

const router = useRouter();
const dialogType = ref('');
const selectedAssistant = ref(null);
const deleteAssistantDialog = ref(null);
const createAssistantDialog = ref(null);

const assistants = ref([]);
const isFetching = ref(false);
const isEmpty = computed(() => !assistants.value.length);

const handleDelete = () => {
  deleteAssistantDialog.value.dialogRef.open();
};

const handleCreate = () => {
  dialogType.value = 'create';
  nextTick(() => {
    if (createAssistantDialog.value) {
      createAssistantDialog.value.dialogRef.open();
    }
  });
};

const handleEdit = () => {
  router.push({
    name: 'saturn_assistants_edit',
    params: { assistantId: selectedAssistant.value.id },
  });
};

const handleViewConnectedInboxes = () => {
  router.push({
    name: 'saturn_assistants_inboxes_index',
    params: { assistantId: selectedAssistant.value.id },
  });
};

const handleAction = ({ action, id }) => {
  selectedAssistant.value = assistants.value.find(
    assistant => id === assistant.id
  );
  nextTick(() => {
    if (action === 'remove' || action === 'delete') {
      handleDelete();
    }
    if (action === 'modify' || action === 'edit') {
      handleEdit();
    }
    if (action === 'viewLinkedInboxes' || action === 'viewConnectedInboxes') {
      handleViewConnectedInboxes();
    }
  });
};

const handleCreateClose = () => {
  dialogType.value = '';
  selectedAssistant.value = null;
  fetchAssistants();
};

const fetchAssistants = async () => {
  isFetching.value = true;
  try {
    const response = await saturnAssistantAPI.get();
    // Jbuilder returns array directly
    assistants.value = Array.isArray(response.data) ? response.data : [];
  } catch (error) {
    console.error('Error fetching Saturn assistants:', error);
    assistants.value = [];
  } finally {
    isFetching.value = false;
  }
};

onMounted(() => {
  fetchAssistants();
});
</script>

<template>
  <SaturnPageLayout
    :page-title="$t('SATURN.ASSISTANTS.HEADER')"
    :action-button-text="$t('SATURN.ASSISTANTS.ADD_NEW')"
    :action-permissions="['administrator']"
    :enable-pagination="false"
    :is-loading="isFetching"
    :has-no-data="isEmpty"
    :total-records="assistants.length"
    :feature-flag-key="FEATURE_FLAGS.SATURN"
    @action="handleCreate"
  >
    <template #subtitle>
      {{ assistants.length }} {{ $t('SATURN.ASSISTANTS.ACTIVE') }}
    </template>
    <template #emptyStateSection>
      <SaturnAssistantPageEmptyState @click="handleCreate" />
    </template>

    <template #contentArea>
      <div class="flex flex-col gap-4">
        <SaturnAssistantItem
          v-for="assistant in assistants"
          :key="assistant.id"
          :assistant-id="assistant.id"
          :assistant-name="assistant.name"
          :assistant-description="assistant.description"
          :last-modified="assistant.updated_at || assistant.created_at"
          :created-at="assistant.created_at"
          :documents-count="assistant.documents_count || 0"
          :responses-count="assistant.responses_count || 0"
          :connected-inboxes="assistant.connected_inboxes || []"
          :is-active="true"
          @item-action="handleAction"
        />
      </div>
    </template>

    <SaturnRemoveDialog
      v-if="selectedAssistant"
      ref="deleteAssistantDialog"
      :target-entity="selectedAssistant"
      entity-type="Assistants"
      i18n-prefix="ASSISTANTS"
    />

    <SaturnCreateDialog
      v-if="dialogType"
      ref="createAssistantDialog"
      :dialog-mode="dialogType === 'create' ? 'create' : 'modify'"
      :existing-assistant="selectedAssistant"
      @dialog-closed="handleCreateClose"
    />
  </SaturnPageLayout>
</template>

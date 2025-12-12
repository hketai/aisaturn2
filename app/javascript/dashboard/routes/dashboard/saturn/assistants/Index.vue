<script setup>
import { computed, onMounted, ref, nextTick } from 'vue';
import { useRouter } from 'vue-router';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

import SaturnPageLayout from 'dashboard/components-next/saturn/SaturnPageLayout.vue';
import SaturnAssistantItem from 'dashboard/components-next/saturn/assistant/SaturnAssistantItem.vue';
import SaturnRemoveDialog from 'dashboard/components-next/saturn/pageComponents/SaturnRemoveDialog.vue';
import SaturnCreateDialog from 'dashboard/components-next/saturn/pageComponents/assistant/SaturnCreateDialog.vue';
import SaturnAssistantPageEmptyState from 'dashboard/components-next/saturn/pageComponents/assistant/SaturnAssistantPageEmptyState.vue';
import ConnectedInboxesModal from 'dashboard/components-next/saturn/assistant/ConnectedInboxesModal.vue';
import ConnectedIntegrationsModal from 'dashboard/components-next/saturn/assistant/ConnectedIntegrationsModal.vue';
import saturnAssistantAPI from 'dashboard/api/saturn/assistant';
import shopifyAPI from 'dashboard/api/integrations/shopify';

const router = useRouter();
const dialogType = ref('');
const selectedAssistant = ref(null);
const deleteAssistantDialog = ref(null);
const createAssistantDialog = ref(null);
const inboxesModal = ref(null);
const integrationsModal = ref(null);
const selectedAssistantForInboxes = ref(null);
const selectedAssistantForIntegrations = ref(null);

const assistants = ref([]);
const accountIntegrations = ref([]);
const isFetching = ref(false);
const isEmpty = computed(() => !assistants.value.length);

const handleDelete = () => {
  deleteAssistantDialog.value.dialogRef.open();
};

const handleDeleteSuccess = () => {
  // Silinen asistanı listeden kaldır
  if (selectedAssistant.value) {
    assistants.value = assistants.value.filter(
      a => a.id !== selectedAssistant.value.id
    );
    selectedAssistant.value = null;
  }
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

const handleManageInboxes = ({ assistantId, assistantName }) => {
  selectedAssistantForInboxes.value = { id: assistantId, name: assistantName };
  nextTick(() => {
    if (inboxesModal.value) {
      inboxesModal.value.dialogRef.open();
    }
  });
};

const handleManageIntegrations = ({ assistantId, assistantName }) => {
  selectedAssistantForIntegrations.value = {
    id: assistantId,
    name: assistantName,
  };
  nextTick(() => {
    if (integrationsModal.value) {
      integrationsModal.value.dialogRef.open();
    }
  });
};

const handleInboxesUpdated = () => {
  fetchAssistants();
};

const handleIntegrationsUpdated = () => {
  fetchAssistants();
  fetchAccountIntegrations();
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
  });
};

const fetchAssistants = async () => {
  isFetching.value = true;
  try {
    const response = await saturnAssistantAPI.get();

    // Jbuilder returns array directly
    // Handle both array and object responses
    if (Array.isArray(response.data)) {
      assistants.value = response.data;
    } else if (response.data && Array.isArray(response.data.payload)) {
      assistants.value = response.data.payload;
    } else if (response.data && Array.isArray(response.data.data)) {
      assistants.value = response.data.data;
    } else {
      assistants.value = [];
    }
  } catch (error) {
    assistants.value = [];
  } finally {
    isFetching.value = false;
  }
};

const handleCreateClose = () => {
  dialogType.value = '';
  selectedAssistant.value = null;
  fetchAssistants();
};

const fetchAccountIntegrations = async () => {
  try {
    const shopifyResponse = await shopifyAPI.getHook();
    const shopifyHook = shopifyResponse.data?.hook || shopifyResponse.hook;

    if (shopifyHook?.id) {
      accountIntegrations.value = [
        {
          id: 'shopify',
          name: 'Shopify',
          icon: 'i-logos-shopify',
          reference_id: shopifyHook.reference_id,
        },
      ];
    } else {
      accountIntegrations.value = [];
    }
  } catch (error) {
    accountIntegrations.value = [];
  }
};

// Helper to get assistant-specific enabled integrations
const getAssistantIntegrations = assistant => {
  const enabledTypes = assistant.enabled_integrations || [];
  return accountIntegrations.value.filter(i => enabledTypes.includes(i.id));
};

onMounted(() => {
  fetchAssistants();
  fetchAccountIntegrations();
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
      <div class="w-full max-w-5xl mx-auto py-4 px-4">
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
            :connected-integrations="getAssistantIntegrations(assistant)"
            :assistant="assistant"
            :all-assistants="assistants"
            :is-active
            @item-action="handleAction"
            @manage-inboxes="handleManageInboxes"
            @manage-integrations="handleManageIntegrations"
            @updated="fetchAssistants"
          />
        </div>
      </div>
    </template>

    <SaturnRemoveDialog
      v-if="selectedAssistant"
      ref="deleteAssistantDialog"
      :target-entity="selectedAssistant"
      entity-type="Assistants"
      i18n-prefix="ASSISTANTS"
      @delete-success="handleDeleteSuccess"
    />

    <SaturnCreateDialog
      v-if="dialogType"
      ref="createAssistantDialog"
      :dialog-mode="dialogType === 'create' ? 'create' : 'modify'"
      :existing-assistant="selectedAssistant"
      @dialog-closed="handleCreateClose"
    />

    <ConnectedInboxesModal
      v-if="selectedAssistantForInboxes"
      ref="inboxesModal"
      :assistant-id="selectedAssistantForInboxes.id"
      :assistant-name="selectedAssistantForInboxes.name"
      @updated="handleInboxesUpdated"
      @close="selectedAssistantForInboxes = null"
    />

    <ConnectedIntegrationsModal
      v-if="selectedAssistantForIntegrations"
      ref="integrationsModal"
      :assistant-id="selectedAssistantForIntegrations.id"
      :assistant-name="selectedAssistantForIntegrations.name"
      @updated="handleIntegrationsUpdated"
      @close="selectedAssistantForIntegrations = null"
    />
  </SaturnPageLayout>
</template>

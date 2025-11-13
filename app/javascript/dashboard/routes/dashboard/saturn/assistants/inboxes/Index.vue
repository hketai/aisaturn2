<script setup>
import { computed, onMounted, ref, nextTick } from 'vue';
import { useRoute } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import SaturnPageLayout from 'dashboard/components-next/saturn/SaturnPageLayout.vue';
import SaturnInboxCard from 'dashboard/components-next/saturn/inbox/SaturnInboxCard.vue';
import SaturnRemoveDialog from 'dashboard/components-next/saturn/pageComponents/SaturnRemoveDialog.vue';
import SaturnConnectInboxDialog from 'dashboard/components-next/saturn/inbox/SaturnConnectInboxDialog.vue';
import saturnInboxesAPI from 'dashboard/api/saturn/inboxes';
import saturnAssistantAPI from 'dashboard/api/saturn/assistant';

const route = useRoute();
const assistantId = Number(route.params.assistantId);
const inboxes = ref([]);
const assistant = ref(null);
const isFetching = ref(false);
const selectedInbox = ref(null);
const deleteInboxDialog = ref(null);
const connectInboxDialog = ref(null);
const showCreateDialog = ref(false);

const isEmpty = computed(() => !inboxes.value.length);

const handleDelete = () => {
  deleteInboxDialog.value.dialogRef.open();
};

const handleCreate = () => {
  showCreateDialog.value = true;
  nextTick(() => connectInboxDialog.value.dialogRef.open());
};

const handleAction = ({ action, id }) => {
  selectedInbox.value = inboxes.value.find(inbox => id === inbox.id);
  nextTick(() => {
    if (action === 'delete') {
      handleDelete();
    }
  });
};

const handleCreateClose = () => {
  showCreateDialog.value = false;
  fetchInboxes();
};

const fetchAssistant = async () => {
  try {
    const response = await saturnAssistantAPI.show(assistantId);
    assistant.value = response.data;
  } catch (error) {
    console.error('Error fetching assistant:', error);
  }
};

const fetchInboxes = async () => {
  isFetching.value = true;
  try {
    const response = await saturnInboxesAPI.get({ assistantId });
    inboxes.value = Array.isArray(response.data) ? response.data : [];
  } catch (error) {
    console.error('Error fetching inboxes:', error);
    inboxes.value = [];
  } finally {
    isFetching.value = false;
  }
};

const onDeleteSuccess = () => {
  fetchInboxes();
};

onMounted(() => {
  fetchAssistant();
  fetchInboxes();
});
</script>

<template>
  <SaturnPageLayout
    :page-title="
      assistant?.name
        ? `${assistant.name} - Inboxes`
        : $t('SATURN.ASSISTANTS.INBOXES.HEADER')
    "
    :action-button-text="$t('SATURN.INBOXES.ADD_NEW')"
    :action-permissions="['administrator']"
    :enable-pagination="false"
    :is-loading="isFetching"
    :has-no-data="isEmpty"
    :total-records="inboxes.length"
    :feature-flag-key="FEATURE_FLAGS.SATURN"
    :return-path="{ name: 'saturn_assistants_edit', params: { assistantId } }"
    @action="handleCreate"
  >
    <template #emptyStateSection>
      <div class="text-center py-12">
        <p class="text-lg text-gray-600">
          {{ $t('SATURN.INBOXES.EMPTY_STATE.TITLE') }}
        </p>
        <p class="text-sm text-gray-500 mt-2">
          {{ $t('SATURN.INBOXES.EMPTY_STATE.SUBTITLE') }}
        </p>
      </div>
    </template>

    <template #contentArea>
      <div class="flex flex-col gap-4">
        <SaturnInboxCard
          v-for="inbox in inboxes"
          :id="inbox.id"
          :key="inbox.id"
          :inbox="inbox"
          @action="handleAction"
        />
      </div>
    </template>

    <SaturnRemoveDialog
      v-if="selectedInbox"
      ref="deleteInboxDialog"
      :target-entity="selectedInbox"
      entity-type="Inboxes"
      i18n-prefix="INBOXES"
      :delete-payload="{
        assistantId,
        inboxId: selectedInbox.id,
      }"
      @delete-success="onDeleteSuccess"
    />

    <SaturnConnectInboxDialog
      v-if="showCreateDialog"
      ref="connectInboxDialog"
      :assistant-id="assistantId"
      @close="handleCreateClose"
    />
  </SaturnPageLayout>
</template>

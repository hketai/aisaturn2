<script setup>
import { computed, onMounted, ref, nextTick } from 'vue';
import { useAlert } from 'dashboard/composables';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import SaturnPageLayout from 'dashboard/components-next/saturn/SaturnPageLayout.vue';
import SaturnToolCard from 'dashboard/components-next/saturn/tool/SaturnToolCard.vue';
import SaturnRemoveDialog from 'dashboard/components-next/saturn/pageComponents/SaturnRemoveDialog.vue';
import saturnToolsAPI from 'dashboard/api/saturn/customTools';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import SaturnToolForm from 'dashboard/components-next/saturn/tool/SaturnToolForm.vue';

const tools = ref([]);
const isFetching = ref(false);
const selectedTool = ref(null);
const deleteToolDialog = ref(null);
const createToolDialog = ref(null);
const showCreateDialog = ref(false);
const dialogType = ref('create');

const isEmpty = computed(() => !tools.value.length);

const handleDelete = () => {
  deleteToolDialog.value.dialogRef.open();
};

const handleCreate = () => {
  dialogType.value = 'create';
  selectedTool.value = null;
  showCreateDialog.value = true;
  nextTick(() => createToolDialog.value.dialogRef.open());
};

const handleEdit = () => {
  dialogType.value = 'edit';
  showCreateDialog.value = true;
  nextTick(() => createToolDialog.value.dialogRef.open());
};

const handleAction = ({ action, id }) => {
  selectedTool.value = tools.value.find(t => t.id === id);
  nextTick(() => {
    if (action === 'delete') {
      handleDelete();
    } else if (action === 'edit') {
      handleEdit();
    }
  });
};

const handleCreateClose = () => {
  showCreateDialog.value = false;
  selectedTool.value = null;
  fetchTools();
};

const fetchTools = async () => {
  isFetching.value = true;
  try {
    const response = await saturnToolsAPI.get();
    tools.value = Array.isArray(response.data) ? response.data : [];
  } catch (error) {
    console.error('Error fetching tools:', error);
    tools.value = [];
  } finally {
    isFetching.value = false;
  }
};

const onDeleteSuccess = () => {
  fetchTools();
};

onMounted(() => {
  fetchTools();
});
</script>

<template>
  <SaturnPageLayout
    :page-title="$t('SATURN.TOOLS.HEADER')"
    :action-button-text="$t('SATURN.TOOLS.ADD_NEW')"
    :action-permissions="['administrator']"
    :enable-pagination="false"
    :is-loading="isFetching"
    :has-no-data="isEmpty"
    :total-records="tools.length"
    :feature-flag-key="FEATURE_FLAGS.SATURN"
    @action="handleCreate"
  >
    <template #emptyStateSection>
      <div class="text-center py-12">
        <p class="text-lg text-gray-600">
          {{ $t('SATURN.TOOLS.EMPTY_STATE.TITLE') }}
        </p>
        <p class="text-sm text-gray-500 mt-2">
          {{ $t('SATURN.TOOLS.EMPTY_STATE.SUBTITLE') }}
        </p>
      </div>
    </template>

    <template #contentArea>
      <div class="flex flex-col gap-4">
        <SaturnToolCard
          v-for="tool in tools"
          :id="tool.id"
          :key="tool.id"
          :title="tool.title"
          :description="tool.description"
          :endpoint-url="tool.endpoint_url"
          :http-method="tool.http_method"
          :enabled="tool.enabled"
          :created-at="tool.created_at"
          @action="handleAction"
        />
      </div>
    </template>

    <SaturnRemoveDialog
      v-if="selectedTool"
      ref="deleteToolDialog"
      :target-entity="selectedTool"
      entity-type="Tools"
      i18n-prefix="TOOLS"
      @delete-success="onDeleteSuccess"
    />

    <Dialog
      v-if="showCreateDialog"
      ref="createToolDialog"
      :title="$t(`SATURN.TOOLS.${dialogType.toUpperCase()}.TITLE`)"
      :show-cancel-button="false"
      :show-confirm-button="false"
      width="2xl"
      @close="handleCreateClose"
    >
      <SaturnToolForm
        :tool="selectedTool"
        :form-mode="dialogType"
        @submit="handleCreateClose"
        @cancel="handleCreateClose"
      />
      <template #footer />
    </Dialog>
  </SaturnPageLayout>
</template>

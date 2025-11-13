<script setup>
import { computed, onMounted, ref, nextTick } from 'vue';
import { useRoute } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import SaturnPageLayout from 'dashboard/components-next/saturn/SaturnPageLayout.vue';
import SaturnScenarioCard from 'dashboard/components-next/saturn/scenario/SaturnScenarioCard.vue';
import SaturnRemoveDialog from 'dashboard/components-next/saturn/pageComponents/SaturnRemoveDialog.vue';
import saturnScenariosAPI from 'dashboard/api/saturn/scenarios';
import saturnAssistantAPI from 'dashboard/api/saturn/assistant';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import SaturnScenarioForm from 'dashboard/components-next/saturn/scenario/SaturnScenarioForm.vue';

const route = useRoute();
const assistantId = Number(route.params.assistantId);
const scenarios = ref([]);
const assistant = ref(null);
const isFetching = ref(false);
const selectedScenario = ref(null);
const deleteScenarioDialog = ref(null);
const createScenarioDialog = ref(null);
const showCreateDialog = ref(false);
const searchQuery = ref('');

const isEmpty = computed(() => !scenarios.value.length);

const filteredScenarios = computed(() => {
  const query = searchQuery.value.trim().toLowerCase();
  if (!query) return scenarios.value;
  return scenarios.value.filter(
    s =>
      s.title.toLowerCase().includes(query) ||
      s.description.toLowerCase().includes(query) ||
      s.instruction.toLowerCase().includes(query)
  );
});

const handleDelete = () => {
  deleteScenarioDialog.value.dialogRef.open();
};

const handleCreate = () => {
  showCreateDialog.value = true;
  nextTick(() => createScenarioDialog.value.dialogRef.open());
};

const handleAction = ({ action, id }) => {
  selectedScenario.value = scenarios.value.find(s => s.id === id);
  nextTick(() => {
    if (action === 'delete') {
      handleDelete();
    }
  });
};

const handleUpdate = async scenarioData => {
  try {
    await saturnScenariosAPI.update({
      assistantId,
      id: scenarioData.id,
      scenario: scenarioData,
    });
    useAlert('Scenario updated successfully');
    fetchScenarios();
  } catch (error) {
    useAlert(error?.message || 'Failed to update scenario');
  }
};

const handleToggle = async ({ id, enabled }) => {
  try {
    await saturnScenariosAPI.update({
      assistantId,
      id,
      scenario: { enabled },
    });
    fetchScenarios();
  } catch (error) {
    useAlert(error?.message || 'Failed to toggle scenario');
  }
};

const handleCreateClose = () => {
  showCreateDialog.value = false;
  fetchScenarios();
};

const fetchAssistant = async () => {
  try {
    const response = await saturnAssistantAPI.show(assistantId);
    assistant.value = response.data;
  } catch (error) {
    console.error('Error fetching assistant:', error);
  }
};

const fetchScenarios = async () => {
  isFetching.value = true;
  try {
    const response = await saturnScenariosAPI.get({ assistantId });
    scenarios.value = Array.isArray(response.data) ? response.data : [];
  } catch (error) {
    console.error('Error fetching scenarios:', error);
    scenarios.value = [];
  } finally {
    isFetching.value = false;
  }
};

const onDeleteSuccess = () => {
  fetchScenarios();
};

onMounted(() => {
  fetchAssistant();
  fetchScenarios();
});
</script>

<template>
  <SaturnPageLayout
    :page-title="
      assistant?.name
        ? `${assistant.name} - Scenarios`
        : $t('SATURN.ASSISTANTS.SCENARIOS.HEADER')
    "
    :action-button-text="$t('SATURN.SCENARIOS.ADD_NEW')"
    :action-permissions="['administrator']"
    :enable-pagination="false"
    :is-loading="isFetching"
    :has-no-data="isEmpty"
    :total-records="filteredScenarios.length"
    :feature-flag-key="FEATURE_FLAGS.SATURN"
    :return-path="{ name: 'saturn_assistants_edit', params: { assistantId } }"
    @action="handleCreate"
  >
    <template #topControls>
      <div v-if="!isEmpty" class="mb-4">
        <Input
          v-model="searchQuery"
          :placeholder="$t('SATURN.SCENARIOS.SEARCH_PLACEHOLDER')"
        />
      </div>
    </template>

    <template #contentArea>
      <div v-if="isEmpty" class="text-center py-12">
        <p class="text-lg text-gray-600">
          {{ $t('SATURN.SCENARIOS.EMPTY_MESSAGE') }}
        </p>
        <Button
          :label="$t('SATURN.SCENARIOS.ADD_NEW')"
          icon="i-lucide-plus"
          class="mt-4"
          @click="handleCreate"
        />
      </div>
      <div v-else class="flex flex-col gap-4">
        <SaturnScenarioCard
          v-for="scenario in filteredScenarios"
          :id="scenario.id"
          :key="scenario.id"
          :title="scenario.title"
          :description="scenario.description"
          :instruction="scenario.instruction"
          :enabled="scenario.enabled"
          @update="handleUpdate"
          @delete="handleAction({ action: 'delete', id: scenario.id })"
          @toggle="handleToggle"
        />
      </div>
    </template>

    <SaturnRemoveDialog
      v-if="selectedScenario"
      ref="deleteScenarioDialog"
      :target-entity="selectedScenario"
      entity-type="Scenarios"
      i18n-prefix="SCENARIOS"
      @delete-success="onDeleteSuccess"
    />

    <Dialog
      v-if="showCreateDialog"
      ref="createScenarioDialog"
      :title="$t('SATURN.SCENARIOS.CREATE.TITLE')"
      :show-cancel-button="false"
      :show-confirm-button="false"
      @close="handleCreateClose"
    >
      <SaturnScenarioForm
        :assistant-id="assistantId"
        @submit="handleCreateClose"
        @cancel="handleCreateClose"
      />
      <template #footer />
    </Dialog>
  </SaturnPageLayout>
</template>

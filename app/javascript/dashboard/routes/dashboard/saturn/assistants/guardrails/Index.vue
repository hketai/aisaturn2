<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { picoSearch } from '@scmmishra/pico-search';
import SaturnPageLayout from 'dashboard/components-next/saturn/SaturnPageLayout.vue';
import SaturnRuleCard from 'dashboard/components-next/saturn/rule/SaturnRuleCard.vue';
import SaturnAddNewRulesInput from 'dashboard/components-next/saturn/rule/SaturnAddNewRulesInput.vue';
import saturnAssistantAPI from 'dashboard/api/saturn/assistant';
import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const route = useRoute();
const assistantId = Number(route.params.assistantId);
const assistant = ref(null);
const guardrails = ref([]);
const isFetching = ref(false);
const searchQuery = ref('');
const newInlineRule = ref('');
const bulkSelectedIds = ref(new Set());
const hoveredCard = ref(null);

const displayGuardrails = computed(() =>
  guardrails.value.map((c, idx) => ({ id: idx, content: c }))
);

const filteredGuardrails = computed(() => {
  const query = searchQuery.value.trim();
  if (!query) return displayGuardrails.value;
  return picoSearch(displayGuardrails.value, query, ['content']);
});

const handleRuleSelect = id => {
  const selected = new Set(bulkSelectedIds.value);
  selected[selected.has(id) ? 'delete' : 'add'](id);
  bulkSelectedIds.value = selected;
};

const handleRuleHover = (isHovered, id) => {
  hoveredCard.value = isHovered ? id : null;
};

const saveGuardrails = async list => {
  try {
    await saturnAssistantAPI.update({
      id: assistantId,
      assistant: { guardrails: list },
    });
    useAlert('Guardrails updated successfully');
    fetchAssistant();
  } catch (error) {
    useAlert(error?.message || 'Failed to update guardrails');
  }
};

const addGuardrail = async content => {
  try {
    const updated = [...guardrails.value, content];
    await saveGuardrails(updated);
  } catch (error) {
    useAlert('Failed to add guardrail');
  }
};

const editGuardrail = async ({ id, content }) => {
  try {
    const updated = [...guardrails.value];
    updated[id] = content;
    await saveGuardrails(updated);
  } catch (error) {
    useAlert('Failed to update guardrail');
  }
};

const deleteGuardrail = async id => {
  try {
    const updated = guardrails.value.filter((_, idx) => idx !== id);
    await saveGuardrails(updated);
  } catch (error) {
    useAlert('Failed to delete guardrail');
  }
};

const bulkDeleteGuardrails = async () => {
  try {
    if (bulkSelectedIds.value.size === 0) return;
    const updated = guardrails.value.filter(
      (_, idx) => !bulkSelectedIds.value.has(idx)
    );
    await saveGuardrails(updated);
    bulkSelectedIds.value.clear();
  } catch (error) {
    useAlert('Failed to delete guardrails');
  }
};

const fetchAssistant = async () => {
  isFetching.value = true;
  try {
    const response = await saturnAssistantAPI.show(assistantId);
    assistant.value = response.data;
    guardrails.value = response.data.guardrails || [];
  } catch (error) {
    console.error('Error fetching assistant:', error);
  } finally {
    isFetching.value = false;
  }
};

onMounted(() => {
  fetchAssistant();
});
</script>

<template>
  <SaturnPageLayout
    :page-title="
      assistant?.name
        ? `${assistant.name} - Guardrails`
        : $t('SATURN.ASSISTANTS.GUARDRAILS.HEADER')
    "
    :enable-pagination="false"
    :is-loading="isFetching"
    :has-no-data="!guardrails.length"
    :total-records="filteredGuardrails.length"
    :feature-flag-key="FEATURE_FLAGS.SATURN"
    :return-path="{ name: 'saturn_assistants_edit', params: { assistantId } }"
  >
    <template #topControls>
      <div
        v-if="guardrails.length > 0"
        class="mb-4 flex justify-between items-center"
      >
        <div class="flex gap-2 items-center">
          <Button
            v-if="bulkSelectedIds.size > 0"
            :label="`Delete ${bulkSelectedIds.size} selected`"
            color="ruby"
            size="sm"
            @click="bulkDeleteGuardrails"
          />
          <Button
            v-if="bulkSelectedIds.size === 0"
            :label="`Select all (${guardrails.length})`"
            variant="ghost"
            size="sm"
            color="slate"
            @click="bulkSelectedIds = new Set(guardrails.map((_, idx) => idx))"
          />
        </div>
        <div class="max-w-[22.5rem] w-full">
          <Input
            v-model="searchQuery"
            :placeholder="$t('SATURN.GUARDRAILS.SEARCH_PLACEHOLDER')"
          />
        </div>
      </div>
    </template>

    <template #contentArea>
      <div v-if="!guardrails.length" class="text-center py-12">
        <p class="text-lg text-gray-600">
          {{ $t('SATURN.GUARDRAILS.EMPTY_MESSAGE') }}
        </p>
      </div>
      <div v-else class="flex flex-col gap-2">
        <SaturnRuleCard
          v-for="guardrail in filteredGuardrails"
          :id="guardrail.id"
          :key="guardrail.id"
          :content="guardrail.content"
          :is-selected="bulkSelectedIds.has(guardrail.id)"
          :selectable="hoveredCard === guardrail.id || bulkSelectedIds.size > 0"
          @select="handleRuleSelect"
          @edit="editGuardrail"
          @delete="deleteGuardrail"
          @hover="isHovered => handleRuleHover(isHovered, guardrail.id)"
        />
        <SaturnAddNewRulesInput
          v-model="newInlineRule"
          :placeholder="$t('SATURN.GUARDRAILS.ADD.PLACEHOLDER')"
          :label="$t('SATURN.GUARDRAILS.ADD.SAVE')"
          @add="addGuardrail"
        />
      </div>
    </template>
  </SaturnPageLayout>
</template>

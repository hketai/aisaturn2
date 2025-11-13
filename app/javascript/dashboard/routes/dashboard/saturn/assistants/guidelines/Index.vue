<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { picoSearch } from '@scmmishra/pico-search';
import SaturnPageLayout from 'dashboard/components-next/saturn/SaturnPageLayout.vue';
import SaturnRuleCard from 'dashboard/components-next/saturn/rule/SaturnRuleCard.vue';
import SaturnAddNewRulesInput from 'dashboard/components-next/saturn/rule/SaturnAddNewRulesInput.vue';
import SaturnAddNewRulesDialog from 'dashboard/components-next/saturn/rule/SaturnAddNewRulesDialog.vue';
import saturnAssistantAPI from 'dashboard/api/saturn/assistant';
import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const route = useRoute();
const assistantId = Number(route.params.assistantId);
const assistant = ref(null);
const guidelines = ref([]);
const isFetching = ref(false);
const searchQuery = ref('');
const newInlineRule = ref('');
const newDialogRule = ref('');
const bulkSelectedIds = ref(new Set());
const hoveredCard = ref(null);

const displayGuidelines = computed(() =>
  guidelines.value.map((c, idx) => ({ id: idx, content: c }))
);

const filteredGuidelines = computed(() => {
  const query = searchQuery.value.trim();
  if (!query) return displayGuidelines.value;
  return picoSearch(displayGuidelines.value, query, ['content']);
});

const handleRuleSelect = id => {
  const selected = new Set(bulkSelectedIds.value);
  selected[selected.has(id) ? 'delete' : 'add'](id);
  bulkSelectedIds.value = selected;
};

const handleRuleHover = (isHovered, id) => {
  hoveredCard.value = isHovered ? id : null;
};

const saveGuidelines = async list => {
  try {
    await saturnAssistantAPI.update({
      id: assistantId,
      assistant: { response_guidelines: list },
    });
    useAlert('Guidelines updated successfully');
    fetchAssistant();
  } catch (error) {
    useAlert(error?.message || 'Failed to update guidelines');
  }
};

const addGuideline = async content => {
  try {
    const updated = [...guidelines.value, content];
    await saveGuidelines(updated);
  } catch (error) {
    useAlert('Failed to add guideline');
  }
};

const editGuideline = async ({ id, content }) => {
  try {
    const updated = [...guidelines.value];
    updated[id] = content;
    await saveGuidelines(updated);
  } catch (error) {
    useAlert('Failed to update guideline');
  }
};

const deleteGuideline = async id => {
  try {
    const updated = guidelines.value.filter((_, idx) => idx !== id);
    await saveGuidelines(updated);
  } catch (error) {
    useAlert('Failed to delete guideline');
  }
};

const bulkDeleteGuidelines = async () => {
  try {
    if (bulkSelectedIds.value.size === 0) return;
    const updated = guidelines.value.filter(
      (_, idx) => !bulkSelectedIds.value.has(idx)
    );
    await saveGuidelines(updated);
    bulkSelectedIds.value.clear();
  } catch (error) {
    useAlert('Failed to delete guidelines');
  }
};

const fetchAssistant = async () => {
  isFetching.value = true;
  try {
    const response = await saturnAssistantAPI.show(assistantId);
    assistant.value = response.data;
    guidelines.value = response.data.response_guidelines || [];
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
        ? `${assistant.name} - Guidelines`
        : $t('SATURN.ASSISTANTS.GUIDELINES.HEADER')
    "
    :enable-pagination="false"
    :is-loading="isFetching"
    :has-no-data="!guidelines.length"
    :total-records="filteredGuidelines.length"
    :feature-flag-key="FEATURE_FLAGS.SATURN"
    :return-path="{ name: 'saturn_assistants_edit', params: { assistantId } }"
  >
    <template #topControls>
      <div
        v-if="guidelines.length > 0"
        class="mb-4 flex justify-between items-center"
      >
        <div class="flex gap-2 items-center">
          <Button
            v-if="bulkSelectedIds.size > 0"
            :label="`Delete ${bulkSelectedIds.size} selected`"
            color="ruby"
            size="sm"
            @click="bulkDeleteGuidelines"
          />
          <Button
            v-if="bulkSelectedIds.size === 0"
            :label="`Select all (${guidelines.length})`"
            variant="ghost"
            size="sm"
            color="slate"
            @click="bulkSelectedIds = new Set(guidelines.map((_, idx) => idx))"
          />
        </div>
        <div class="max-w-[22.5rem] w-full">
          <Input
            v-model="searchQuery"
            :placeholder="$t('SATURN.GUIDELINES.SEARCH_PLACEHOLDER')"
          />
        </div>
      </div>
    </template>

    <template #contentArea>
      <div v-if="!guidelines.length" class="text-center py-12">
        <p class="text-lg text-gray-600">
          {{ $t('SATURN.GUIDELINES.EMPTY_MESSAGE') }}
        </p>
      </div>
      <div v-else class="flex flex-col gap-2">
        <SaturnRuleCard
          v-for="guideline in filteredGuidelines"
          :id="guideline.id"
          :key="guideline.id"
          :content="guideline.content"
          :is-selected="bulkSelectedIds.has(guideline.id)"
          :selectable="hoveredCard === guideline.id || bulkSelectedIds.size > 0"
          @select="handleRuleSelect"
          @edit="editGuideline"
          @delete="deleteGuideline"
          @hover="isHovered => handleRuleHover(isHovered, guideline.id)"
        />
        <SaturnAddNewRulesInput
          v-model="newInlineRule"
          :placeholder="$t('SATURN.GUIDELINES.ADD.PLACEHOLDER')"
          :label="$t('SATURN.GUIDELINES.ADD.SAVE')"
          @add="addGuideline"
        />
      </div>
    </template>
  </SaturnPageLayout>
</template>

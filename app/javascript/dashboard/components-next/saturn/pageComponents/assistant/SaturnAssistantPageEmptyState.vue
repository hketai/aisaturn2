<script setup>
import EmptyStateLayout from 'dashboard/components-next/EmptyStateLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import SaturnAssistantItem from 'dashboard/components-next/saturn/assistant/SaturnAssistantItem.vue';
import FeatureSpotlight from 'dashboard/components-next/feature-spotlight/FeatureSpotlight.vue';

const emit = defineEmits(['click']);

const sampleAssistants = [
  {
    id: 1,
    name: 'Customer Support Assistant',
    description: 'Helps customers with common questions and issues',
    created_at: Date.now() / 1000 - 86400,
    updated_at: Date.now() / 1000 - 3600,
    documents_count: 5,
    responses_count: 12,
    connected_inboxes: [],
  },
  {
    id: 2,
    name: 'Sales Assistant',
    description: 'Assists with product inquiries and sales questions',
    created_at: Date.now() / 1000 - 172800,
    updated_at: Date.now() / 1000 - 7200,
    documents_count: 3,
    responses_count: 8,
    connected_inboxes: [],
  },
];

const onClick = () => {
  emit('click');
};
</script>

<template>
  <FeatureSpotlight
    :title="$t('SATURN.ASSISTANTS.EMPTY_STATE.FEATURE_SPOTLIGHT.TITLE')"
    :note="$t('SATURN.ASSISTANTS.EMPTY_STATE.FEATURE_SPOTLIGHT.NOTE')"
    class="mb-8"
  />
  <EmptyStateLayout
    :title="$t('SATURN.ASSISTANTS.EMPTY_STATE.TITLE')"
    :subtitle="$t('SATURN.ASSISTANTS.EMPTY_STATE.SUBTITLE')"
    :action-perms="['administrator']"
  >
    <template #empty-state-item>
      <div class="grid grid-cols-1 gap-4 p-px overflow-hidden">
        <SaturnAssistantItem
          v-for="(assistant, index) in sampleAssistants.slice(0, 5)"
          :key="`assistant-${index}`"
          :assistant-id="assistant.id"
          :assistant-name="assistant.name"
          :assistant-description="assistant.description"
          :last-modified="assistant.updated_at"
          :created-at="assistant.created_at"
          :documents-count="assistant.documents_count"
          :responses-count="assistant.responses_count"
          :connected-inboxes="assistant.connected_inboxes"
          :is-active="true"
        />
      </div>
    </template>
    <template #actions>
      <Button
        :label="$t('SATURN.ASSISTANTS.ADD_NEW')"
        icon="i-lucide-plus"
        @click="onClick"
      />
    </template>
  </EmptyStateLayout>
</template>

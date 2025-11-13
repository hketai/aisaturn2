<script setup>
import EmptyStateLayout from 'dashboard/components-next/EmptyStateLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import SaturnAssistantItem from '../../assistant/SaturnAssistantItem.vue';
import FeatureSpotlight from 'dashboard/components-next/feature-spotlight/FeatureSpotlight.vue';

const emit = defineEmits(['createClick']);

const sampleAssistants = [
  {
    id: 1,
    name: 'Customer Support Assistant',
    description: 'Helps customers with common questions and issues',
    created_at: Date.now() - 86400000,
  },
  {
    id: 2,
    name: 'Sales Assistant',
    description: 'Assists with product information and sales inquiries',
    created_at: Date.now() - 172800000,
  },
  {
    id: 3,
    name: 'Technical Support',
    description: 'Provides technical assistance and troubleshooting',
    created_at: Date.now() - 259200000,
  },
  {
    id: 4,
    name: 'FAQ Assistant',
    description: 'Answers frequently asked questions',
    created_at: Date.now() - 345600000,
  },
  {
    id: 5,
    name: 'Onboarding Helper',
    description: 'Guides new users through the setup process',
    created_at: Date.now() - 432000000,
  },
];

const onCreateClick = () => {
  emit('createClick');
};
</script>

<template>
  <FeatureSpotlight
    :title="$t('SATURN.ASSISTANTS.EMPTY_STATE.FEATURE_SPOTLIGHT.TITLE')"
    :note="$t('SATURN.ASSISTANTS.EMPTY_STATE.FEATURE_SPOTLIGHT.NOTE')"
    fallback-thumbnail="/assets/images/dashboard/saturn/assistant-light.svg"
    fallback-thumbnail-dark="/assets/images/dashboard/saturn/assistant-dark.svg"
    learn-more-url="https://aisaturn.co/saturn-assistant"
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
          v-for="(assistant, index) in sampleAssistants"
          :key="`saturn-assistant-${index}`"
          :assistant-id="assistant.id"
          :assistant-name="assistant.name"
          :assistant-description="assistant.description"
          :last-modified="assistant.created_at"
        />
      </div>
    </template>
    <template #actions>
      <Button
        :label="$t('SATURN.ASSISTANTS.ADD_NEW')"
        icon="i-lucide-plus"
        @click="onCreateClick"
      />
    </template>
  </EmptyStateLayout>
</template>

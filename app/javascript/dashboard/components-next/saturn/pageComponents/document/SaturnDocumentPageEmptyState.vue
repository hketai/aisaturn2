<script setup>
import EmptyStateLayout from 'dashboard/components-next/EmptyStateLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import SaturnDocumentCard from 'dashboard/components-next/saturn/document/SaturnDocumentCard.vue';
import FeatureSpotlight from 'dashboard/components-next/feature-spotlight/FeatureSpotlight.vue';

const emit = defineEmits(['click']);

const sampleDocuments = [
  {
    id: 1,
    name: 'Product Guide',
    external_link: 'https://example.com/product-guide.pdf',
    created_at: Date.now() / 1000 - 86400,
    assistant: { id: 1, name: 'Support Assistant' },
  },
  {
    id: 2,
    name: 'FAQ Document',
    external_link: 'https://example.com/faq.pdf',
    created_at: Date.now() / 1000 - 172800,
    assistant: { id: 1, name: 'Support Assistant' },
  },
];

const onClick = () => {
  emit('click');
};
</script>

<template>
  <FeatureSpotlight
    :title="$t('SATURN.DOCUMENTS.EMPTY_STATE.FEATURE_SPOTLIGHT.TITLE')"
    :note="$t('SATURN.DOCUMENTS.EMPTY_STATE.FEATURE_SPOTLIGHT.NOTE')"
    class="mb-8"
  />
  <EmptyStateLayout
    :title="$t('SATURN.DOCUMENTS.EMPTY_STATE.TITLE')"
    :subtitle="$t('SATURN.DOCUMENTS.EMPTY_STATE.SUBTITLE')"
    :action-perms="['administrator']"
  >
    <template #empty-state-item>
      <div class="grid grid-cols-1 gap-4 p-px overflow-hidden">
        <SaturnDocumentCard
          v-for="(document, index) in sampleDocuments.slice(0, 5)"
          :id="document.id"
          :key="`document-${index}`"
          :name="document.name"
          :assistant="document.assistant"
          :external-link="document.external_link"
          :created-at="document.created_at"
        />
      </div>
    </template>
    <template #actions>
      <Button
        :label="$t('SATURN.DOCUMENTS.ADD_NEW')"
        icon="i-lucide-plus"
        @click="onClick"
      />
    </template>
  </EmptyStateLayout>
</template>

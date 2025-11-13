<script setup>
import EmptyStateLayout from 'dashboard/components-next/EmptyStateLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import FeatureSpotlight from 'dashboard/components-next/feature-spotlight/FeatureSpotlight.vue';

const emit = defineEmits(['click']);

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
    <template #actions>
      <Button
        :label="$t('SATURN.DOCUMENTS.ADD_NEW')"
        icon="i-lucide-plus"
        @click="onClick"
      />
    </template>
  </EmptyStateLayout>
</template>

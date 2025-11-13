<script setup>
import EmptyStateLayout from 'dashboard/components-next/EmptyStateLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import SaturnResponseCard from 'dashboard/components-next/saturn/response/SaturnResponseCard.vue';
import FeatureSpotlight from 'dashboard/components-next/feature-spotlight/FeatureSpotlight.vue';

const emit = defineEmits(['click']);

const sampleResponses = [
  {
    id: 1,
    question: 'How do I reset my password?',
    answer:
      'You can reset your password by clicking on "Forgot Password" on the login page.',
    status: 'approved',
    created_at: Date.now() / 1000 - 86400,
    assistant: { id: 1, name: 'Support Assistant' },
  },
  {
    id: 2,
    question: 'What are your business hours?',
    answer: 'Our business hours are Monday to Friday, 9 AM to 5 PM EST.',
    status: 'approved',
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
    :title="$t('SATURN.RESPONSES.EMPTY_STATE.FEATURE_SPOTLIGHT.TITLE')"
    :note="$t('SATURN.RESPONSES.EMPTY_STATE.FEATURE_SPOTLIGHT.NOTE')"
    class="mb-8"
  />
  <EmptyStateLayout
    :title="$t('SATURN.RESPONSES.EMPTY_STATE.TITLE')"
    :subtitle="$t('SATURN.RESPONSES.EMPTY_STATE.SUBTITLE')"
    :action-perms="['administrator']"
  >
    <template #empty-state-item>
      <div class="grid grid-cols-1 gap-4 p-px overflow-hidden">
        <SaturnResponseCard
          v-for="(response, index) in sampleResponses.slice(0, 5)"
          :id="response.id"
          :key="`response-${index}`"
          :question="response.question"
          :answer="response.answer"
          :status="response.status"
          :assistant="response.assistant"
          :created-at="response.created_at"
        />
      </div>
    </template>
    <template #actions>
      <Button
        :label="$t('SATURN.RESPONSES.ADD_NEW')"
        icon="i-lucide-plus"
        @click="onClick"
      />
    </template>
  </EmptyStateLayout>
</template>

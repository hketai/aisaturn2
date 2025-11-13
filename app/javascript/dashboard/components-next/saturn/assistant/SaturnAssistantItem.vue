<script setup>
import { useRouter } from 'vue-router';
import CardLayout from 'dashboard/components-next/CardLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import SaturnIcon from 'dashboard/components-next/icon/SaturnIcon.vue';

const props = defineProps({
  assistantId: {
    type: Number,
    required: true,
  },
  assistantName: {
    type: String,
    required: true,
  },
  assistantDescription: {
    type: String,
    required: true,
  },
  documentsCount: {
    type: Number,
    default: 0,
  },
  responsesCount: {
    type: Number,
    default: 0,
  },
  connectedInboxes: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['itemAction']);
const router = useRouter();

const handleEdit = () => {
  emit('itemAction', { action: 'modify', id: props.assistantId });
};

const handleDelete = () => {
  emit('itemAction', { action: 'remove', id: props.assistantId });
};

const handleViewInboxes = () => {
  router.push({
    name: 'saturn_assistants_inboxes_index',
    params: { assistantId: props.assistantId },
  });
};

const handleWorkingHours = () => {
  router.push({
    name: 'saturn_assistants_working_hours_index',
    params: { assistantId: props.assistantId },
  });
};

const handleHandoffSettings = () => {
  router.push({
    name: 'saturn_assistants_handoff_index',
    params: { assistantId: props.assistantId },
  });
};
</script>

<template>
  <CardLayout class="saturn-assistant-card">
    <div class="saturn-card-header">
      <div class="saturn-assistant-info">
        <div class="saturn-assistant-icon">
          <SaturnIcon class="size-6" />
        </div>
        <div class="saturn-assistant-details">
          <div class="saturn-assistant-title-row">
            <h3 class="saturn-assistant-name">{{ assistantName }}</h3>
          </div>
          <p class="saturn-assistant-role">{{ assistantDescription }}</p>
        </div>
      </div>
      <div class="saturn-card-actions">
        <Button
          icon="i-lucide-pencil"
          color="slate"
          size="xs"
          variant="ghost"
          class="saturn-action-btn"
          @click="handleEdit"
        />
        <Button
          icon="i-lucide-trash-2"
          color="ruby"
          size="xs"
          variant="ghost"
          class="saturn-action-btn"
          @click="handleDelete"
        />
      </div>
    </div>

    <div class="saturn-card-content">
      <div class="saturn-stats">
        <div class="saturn-stat-item">
          <i class="i-lucide-file-text saturn-stat-icon" />
          <div class="saturn-stat-info">
            <span class="saturn-stat-label">
              {{ $t('SATURN.ASSISTANTS.DOCUMENTS') }}
            </span>
            <span class="saturn-stat-value">{{ props.documentsCount }}</span>
          </div>
        </div>
        <div class="saturn-stat-item">
          <i class="i-lucide-message-circle saturn-stat-icon" />
          <div class="saturn-stat-info">
            <span class="saturn-stat-label">
              {{ $t('SATURN.ASSISTANTS.RESPONSES') }}
            </span>
            <span class="saturn-stat-value">{{ props.responsesCount }}</span>
          </div>
        </div>
      </div>

      <div class="saturn-card-footer">
        <div class="saturn-footer-buttons">
          <Button
            variant="outline"
            color="blue"
            size="sm"
            class="saturn-footer-button"
            @click="handleViewInboxes"
          >
            <template v-if="props.connectedInboxes.length > 0">
              {{ $t('SATURN.ASSISTANTS.OPTIONS.CHANNEL') }}
              <span>{{ ` (${props.connectedInboxes.length})` }}</span>
            </template>
            <template v-else>
              {{ $t('SATURN.ASSISTANTS.OPTIONS.CONNECT_CHANNEL') }}
            </template>
          </Button>
          <Button
            variant="outline"
            color="slate"
            size="sm"
            class="saturn-footer-button"
            @click="handleWorkingHours"
          >
            {{ $t('SATURN.ASSISTANTS.OPTIONS.WORKING_HOURS') }}
          </Button>
          <Button
            variant="outline"
            color="slate"
            size="sm"
            class="saturn-footer-button"
            @click="handleHandoffSettings"
          >
            {{ $t('SATURN.ASSISTANTS.OPTIONS.HANDOFF_SETTINGS') }}
          </Button>
        </div>
      </div>
    </div>
  </CardLayout>
</template>

<style scoped>
.saturn-assistant-card {
  @apply bg-n-slate-1 border border-n-slate-4 rounded-lg p-4;
}

body.dark .saturn-assistant-card,
.htw-dark .saturn-assistant-card {
  @apply bg-slate-800 border-slate-700;
}

.saturn-card-header {
  @apply flex items-start justify-between gap-4 mb-4;
}

.saturn-assistant-info {
  @apply flex items-start gap-3 flex-1;
}

.saturn-assistant-icon {
  @apply flex-shrink-0 w-10 h-10 rounded-lg bg-n-blue-9 flex items-center justify-center text-white;
}

.saturn-assistant-details {
  @apply flex-1 min-w-0;
}

.saturn-assistant-title-row {
  @apply flex items-center gap-2 mb-1;
}

.saturn-assistant-name {
  @apply text-base font-semibold text-n-slate-12 m-0;
}

body.dark .saturn-assistant-name,
.htw-dark .saturn-assistant-name {
  @apply text-slate-100;
}

.saturn-assistant-role {
  @apply text-sm text-n-slate-11 m-0;
}

body.dark .saturn-assistant-role,
.htw-dark .saturn-assistant-role {
  @apply text-slate-400;
}

.saturn-card-actions {
  @apply flex items-center gap-1 flex-shrink-0;
}

.saturn-action-btn {
  @apply opacity-70 hover:opacity-100 transition-opacity;
}

.saturn-card-content {
  @apply space-y-4;
}

.saturn-stats {
  @apply flex gap-6;
}

.saturn-stat-item {
  @apply flex items-center gap-2;
}

.saturn-stat-icon {
  @apply w-5 h-5 text-n-slate-11;
}

body.dark .saturn-stat-icon,
.htw-dark .saturn-stat-icon {
  @apply text-slate-400;
}

.saturn-stat-info {
  @apply flex flex-col;
}

.saturn-stat-label {
  @apply text-xs text-n-slate-11;
}

body.dark .saturn-stat-label,
.htw-dark .saturn-stat-label {
  @apply text-slate-400;
}

.saturn-stat-value {
  @apply text-sm font-semibold text-n-slate-12;
}

body.dark .saturn-stat-value,
.htw-dark .saturn-stat-value {
  @apply text-slate-100;
}

.saturn-card-footer {
  @apply pt-4 border-t border-n-slate-4;
}

body.dark .saturn-card-footer,
.htw-dark .saturn-card-footer {
  @apply border-slate-700;
}

.saturn-footer-buttons {
  @apply flex flex-wrap gap-2 justify-end;
}

.saturn-footer-button {
  @apply text-sm font-medium cursor-pointer;
}
</style>

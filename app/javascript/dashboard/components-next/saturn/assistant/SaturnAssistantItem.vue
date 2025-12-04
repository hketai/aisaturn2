<script setup>
import { useRouter } from 'vue-router';
import Button from 'dashboard/components-next/button/Button.vue';
import SaturnIcon from 'dashboard/components-next/icon/SaturnIcon.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

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
  connectedIntegrations: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['itemAction', 'manageInboxes', 'manageIntegrations']);
const router = useRouter();

const handleEdit = () => {
  emit('itemAction', { action: 'modify', id: props.assistantId });
};

const handleDelete = () => {
  emit('itemAction', { action: 'remove', id: props.assistantId });
};

const handleManageInboxes = () => {
  emit('manageInboxes', { 
    assistantId: props.assistantId, 
    assistantName: props.assistantName 
  });
};

const handleManageIntegrations = () => {
  emit('manageIntegrations', { 
    assistantId: props.assistantId, 
    assistantName: props.assistantName 
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
  <div
    class="group relative bg-n-solid-2 border border-n-weak rounded-xl p-5 hover:border-n-slate-7 hover:shadow-md transition-all duration-200"
  >
    <!-- Card Header -->
    <div class="flex items-start gap-4">
      <div
        class="size-14 flex justify-center items-center bg-n-blue-9 rounded-xl ring-1 ring-n-weak"
      >
        <SaturnIcon class="size-7 text-white" />
      </div>
      <div class="flex-1 min-w-0">
        <h3 class="font-semibold text-n-slate-12 truncate">
          {{ assistantName }}
        </h3>
        <p class="text-sm text-n-slate-11 line-clamp-2 mt-1">
          {{ assistantDescription }}
        </p>
      </div>
    </div>

    <!-- Stats -->
    <div class="mt-4 flex gap-4">
      <div class="flex items-center gap-2">
        <i class="i-lucide-file-text size-4 text-n-slate-11" />
        <span class="text-sm text-n-slate-11">
          {{ props.documentsCount }} {{ $t('SATURN.ASSISTANTS.DOCUMENTS') }}
        </span>
      </div>
      <div class="flex items-center gap-2">
        <i class="i-lucide-message-circle size-4 text-n-slate-11" />
        <span class="text-sm text-n-slate-11">
          {{ props.responsesCount }} {{ $t('SATURN.ASSISTANTS.RESPONSES') }}
        </span>
      </div>
    </div>

    <!-- Channel Status -->
    <div class="mt-3">
      <!-- Connected Channels -->
      <div v-if="props.connectedInboxes.length > 0" class="flex flex-wrap gap-1.5">
        <span
          v-for="inbox in props.connectedInboxes"
          :key="inbox.id"
          class="inline-flex items-center gap-1.5 px-2.5 py-1 text-xs font-medium rounded-full bg-g-success-subtle text-g-success"
        >
          <i class="i-lucide-check-circle size-3" />
          {{ inbox.name }}
        </span>
      </div>
      <!-- No Channel Connected - Warning Alert -->
      <div
        v-else
        class="flex flex-col gap-2 p-3 rounded-lg bg-n-amber-3 border border-n-amber-6"
      >
        <div class="flex items-center gap-2">
          <i class="i-lucide-alert-triangle size-4 text-n-amber-11 flex-shrink-0" />
          <p class="text-xs font-medium text-n-amber-11">
            {{ $t('SATURN.ASSISTANTS.NO_CHANNEL_WARNING') }}
          </p>
        </div>
        <Button
          icon="i-lucide-plug"
          xs
          class="w-full bg-n-amber-9 hover:bg-n-amber-10 text-white border-0"
          @click="handleManageInboxes"
        >
          {{ $t('SATURN.ASSISTANTS.OPTIONS.CONNECT_CHANNEL') }}
        </Button>
      </div>
    </div>

    <!-- Integrations Status -->
    <div class="mt-3">
      <!-- Connected Integrations -->
      <div v-if="props.connectedIntegrations.length > 0" class="flex flex-wrap gap-1.5">
        <span
          v-for="integration in props.connectedIntegrations"
          :key="integration.id"
          class="inline-flex items-center gap-1.5 px-2.5 py-1 text-xs font-medium rounded-full bg-n-iris-3 text-n-iris-11"
        >
          <Icon :icon="integration.icon || 'i-lucide-puzzle'" class="size-3" />
          {{ integration.name }}
        </span>
      </div>
      <!-- No Integration - Add Button -->
      <button
        v-else
        class="w-full flex items-center justify-center gap-2 px-3 py-2 text-xs font-medium text-n-slate-11 bg-n-slate-3 hover:bg-n-slate-4 rounded-lg transition-colors border border-dashed border-n-slate-6"
        @click="handleManageIntegrations"
      >
        <i class="i-lucide-puzzle size-4" />
        Entegrasyon Bağla
      </button>
    </div>

    <!-- Card Actions -->
    <div
      class="mt-4 pt-4 border-t border-n-weak flex items-center justify-between"
    >
      <div class="flex gap-2">
        <Button
          v-if="props.connectedInboxes.length > 0"
          icon="i-lucide-inbox"
          xs
          slate
          faded
          title="Kanalları Yönet"
          @click="handleManageInboxes"
        />
        <Button
          v-if="props.connectedIntegrations.length > 0"
          icon="i-lucide-puzzle"
          xs
          slate
          faded
          title="Entegrasyonları Yönet"
          @click="handleManageIntegrations"
        />
        <Button
          icon="i-lucide-clock"
          xs
          slate
          faded
          title="Çalışma Saatleri"
          @click="handleWorkingHours"
        />
        <Button
          icon="i-lucide-user-cog"
          xs
          slate
          faded
          title="Devir Ayarları"
          @click="handleHandoffSettings"
        />
      </div>
      <div class="flex gap-2">
        <Button
          icon="i-lucide-pencil"
          xs
          slate
          faded
          title="Düzenle"
          @click="handleEdit"
        />
        <Button
          icon="i-lucide-trash-2"
          xs
          ruby
          faded
          title="Sil"
          @click="handleDelete"
        />
      </div>
    </div>
  </div>
</template>

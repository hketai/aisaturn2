<script setup>
import { useRouter } from 'vue-router';
import Button from 'dashboard/components-next/button/Button.vue';
import SaturnIcon from 'dashboard/components-next/icon/SaturnIcon.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { getInboxIconByType } from 'dashboard/helper/inbox.js';

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
    assistantName: props.assistantName,
  });
};

const handleManageIntegrations = () => {
  emit('manageIntegrations', {
    assistantId: props.assistantId,
    assistantName: props.assistantName,
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
    class="bg-n-slate-1 border border-n-slate-4 rounded-xl overflow-hidden hover:shadow-lg transition-all duration-300"
  >
    <!-- Main Content Row -->
    <div class="flex flex-col lg:flex-row">
      <!-- Left Section - Avatar & Info -->
      <div class="flex-1 p-5 flex items-start gap-4">
        <div
          class="size-14 flex-shrink-0 flex justify-center items-center bg-gradient-to-br from-n-blue-9 to-n-violet-9 rounded-xl shadow-lg"
        >
          <SaturnIcon class="size-7 text-white" />
        </div>
        <div class="flex-1 min-w-0">
          <div class="flex items-center gap-2">
            <h3 class="text-lg font-semibold text-n-slate-12 truncate">
              {{ assistantName }}
            </h3>
            <span
              v-if="props.connectedInboxes.length > 0"
              class="px-2 py-0.5 text-xs font-medium rounded-full bg-n-teal-3 text-n-teal-11"
            >
              Aktif
            </span>
          </div>
          <p class="text-sm text-n-slate-11 mt-1 line-clamp-2">
            {{ assistantDescription }}
          </p>

          <!-- Stats Row -->
          <div class="flex items-center gap-4 mt-3">
            <div class="flex items-center gap-1.5 text-n-slate-10">
              <i class="i-lucide-file-text size-4" />
              <span class="text-sm font-medium">{{ props.documentsCount }}</span>
              <span class="text-xs">Belgeler</span>
            </div>
            <div class="flex items-center gap-1.5 text-n-slate-10">
              <i class="i-lucide-message-circle size-4" />
              <span class="text-sm font-medium">{{ props.responsesCount }}</span>
              <span class="text-xs">SSS</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Center Section - Channels & Integrations -->
      <div class="flex-1 p-5 border-t lg:border-t-0 lg:border-l border-n-slate-4 bg-n-slate-2/50">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4 h-full">
          <!-- Channels -->
          <div>
            <div class="flex items-center gap-2 mb-2">
              <i class="i-lucide-inbox size-4 text-n-slate-10" />
              <span class="text-xs font-medium text-n-slate-11 uppercase tracking-wide">Kanallar</span>
              <button
                v-if="props.connectedInboxes.length > 0"
                class="text-xs text-n-blue-11 hover:text-n-blue-12 hover:underline ml-1"
                @click="handleManageInboxes"
              >
                Yönet
              </button>
            </div>
            <div v-if="props.connectedInboxes.length > 0" class="flex flex-wrap gap-1.5">
              <span
                v-for="inbox in props.connectedInboxes"
                :key="inbox.id"
                class="inline-flex items-center gap-1.5 px-2.5 py-1 text-xs font-medium rounded-lg bg-n-teal-3 text-n-teal-11 border border-n-teal-6"
              >
                <Icon
                  :icon="getInboxIconByType(inbox.channel_type, inbox.medium)"
                  class="size-3"
                />
                {{ inbox.name }}
              </span>
            </div>
            <button
              v-else
              class="w-full flex items-center justify-center gap-2 px-3 py-2.5 text-xs font-medium text-n-slate-11 bg-n-slate-3 hover:bg-n-slate-4 rounded-lg transition-colors border border-dashed border-n-slate-6"
              @click="handleManageInboxes"
            >
              <i class="i-lucide-plus size-4" />
              Kanal Ekle
            </button>
          </div>

          <!-- Integrations -->
          <div>
            <div class="flex items-center gap-2 mb-2">
              <i class="i-lucide-puzzle size-4 text-n-slate-10" />
              <span class="text-xs font-medium text-n-slate-11 uppercase tracking-wide">Entegrasyonlar</span>
              <button
                v-if="props.connectedIntegrations.length > 0"
                class="text-xs text-n-blue-11 hover:text-n-blue-12 hover:underline ml-1"
                @click="handleManageIntegrations"
              >
                Yönet
              </button>
            </div>
            <div v-if="props.connectedIntegrations.length > 0" class="flex flex-wrap gap-1.5">
              <span
                v-for="integration in props.connectedIntegrations"
                :key="integration.id"
                class="inline-flex items-center gap-1.5 px-2.5 py-1 text-xs font-medium rounded-lg bg-n-iris-3 text-n-iris-11 border border-n-iris-6"
              >
                <Icon :icon="integration.icon || 'i-lucide-puzzle'" class="size-3" />
                {{ integration.name }}
              </span>
            </div>
            <button
              v-else
              class="w-full flex items-center justify-center gap-2 px-3 py-2.5 text-xs font-medium text-n-slate-11 bg-n-slate-3 hover:bg-n-slate-4 rounded-lg transition-colors border border-dashed border-n-slate-6"
              @click="handleManageIntegrations"
            >
              <i class="i-lucide-plus size-4" />
              Entegrasyon Ekle
            </button>
          </div>
        </div>
      </div>

      <!-- Right Section - Actions -->
      <div class="p-5 border-t lg:border-t-0 lg:border-l border-n-slate-4 flex lg:flex-col items-center justify-center gap-2 bg-n-slate-2/30">
        <button
          class="w-full flex items-center gap-2 px-3 py-2 text-sm font-medium text-n-slate-12 bg-n-slate-3 hover:bg-n-slate-4 rounded-lg transition-colors"
          @click="handleEdit"
        >
          <i class="i-lucide-pencil size-4" />
          Düzenle
        </button>
        <button
          class="w-full flex items-center gap-2 px-3 py-2 text-sm font-medium text-n-slate-12 bg-n-slate-3 hover:bg-n-slate-4 rounded-lg transition-colors"
          @click="handleWorkingHours"
        >
          <i class="i-lucide-clock size-4" />
          Çalışma Saatleri
        </button>
        <button
          class="w-full flex items-center gap-2 px-3 py-2 text-sm font-medium text-n-slate-12 bg-n-slate-3 hover:bg-n-slate-4 rounded-lg transition-colors"
          @click="handleHandoffSettings"
        >
          <i class="i-lucide-user-cog size-4" />
          Devir Ayarları
        </button>
        <button
          class="w-full flex items-center gap-2 px-3 py-2 text-sm font-medium text-n-ruby-11 bg-n-ruby-3 hover:bg-n-ruby-4 rounded-lg transition-colors"
          @click="handleDelete"
        >
          <i class="i-lucide-trash-2 size-4" />
          Sil
        </button>
      </div>
    </div>
  </div>
</template>

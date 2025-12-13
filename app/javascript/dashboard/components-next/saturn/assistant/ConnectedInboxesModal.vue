<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import { useStore } from 'vuex';
import saturnInboxesAPI from 'dashboard/api/saturn/inboxes';
import saturnAssistantAPI from 'dashboard/api/saturn/assistant';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const router = useRouter();

const props = defineProps({
  assistantId: {
    type: Number,
    required: true,
  },
  assistantName: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['close', 'updated']);

// Hardcoded translations
const translations = {
  TITLE: 'Kanal Yönetimi',
  DESCRIPTION: 'Asistana bağlanacak kanalları yönetin',
  NO_INBOXES: 'Henüz kanal oluşturulmamış.',
  ADD_CHANNEL: 'Kanal Ekle',
  SELECT_HINT: 'Asistana bağlamak istediğiniz kanalları seçin',
  CONNECTED: 'Bağlı',
  CONNECTED_TO: 'Bağlı:',
  SELECTED: 'kanal seçildi',
  UNSAVED_CHANGES: 'Kaydedilmemiş değişiklikler var',
  SAVE_SUCCESS: 'Kanal bağlantıları başarıyla güncellendi.',
  SAVE_ERROR: 'Kanal bağlantıları güncellenirken bir hata oluştu.',
  FETCH_ERROR: 'Bağlı kanallar yüklenirken bir hata oluştu.',
  CANCEL: 'İptal',
  SAVE: 'Kaydet',
};

const store = useStore();

const dialogRef = ref(null);
const isLoading = ref(false);
const isSaving = ref(false);
const connectedInboxIds = ref([]);
const selectedInboxIds = ref([]);
const inboxToAssistantMap = ref({}); // Maps inbox IDs to assistant names

const allInboxes = useMapGetter('inboxes/getInboxes');

// Fetch all assistants to get inbox assignments
const fetchAllAssistants = async () => {
  try {
    const response = await saturnAssistantAPI.get();
    const assistants = Array.isArray(response.data) ? response.data : [];

    // Build map of inbox -> assistant name (excluding current assistant)
    const map = {};
    assistants.forEach(assistant => {
      if (assistant.id !== props.assistantId && assistant.connected_inboxes) {
        assistant.connected_inboxes.forEach(inbox => {
          map[inbox.id] = assistant.name;
        });
      }
    });
    inboxToAssistantMap.value = map;
  } catch (error) {
    console.error('Error fetching assistants:', error);
  }
};

// Check if inbox is used by another assistant
const isUsedByOtherAssistant = inboxId => {
  return !!inboxToAssistantMap.value[inboxId];
};

// Get the assistant name that's using the inbox
const getAssistantUsingInbox = inboxId => {
  return inboxToAssistantMap.value[inboxId] || '';
};

// Fetch connected inboxes for this assistant
const fetchConnectedInboxes = async () => {
  isLoading.value = true;
  try {
    await fetchAllAssistants();

    const response = await saturnInboxesAPI.get({
      assistantId: props.assistantId,
    });
    const connected = Array.isArray(response.data) ? response.data : [];
    connectedInboxIds.value = connected.map(i => i.id);
    selectedInboxIds.value = [...connectedInboxIds.value];
  } catch (error) {
    console.error('Error fetching connected inboxes:', error);
    useAlert(translations.FETCH_ERROR);
  } finally {
    isLoading.value = false;
  }
};

// Sorted inbox list
const sortedInboxes = computed(() => {
  return (
    allInboxes.value?.slice().sort((a, b) => a.name.localeCompare(b.name)) || []
  );
});

// Check if an inbox is selected
const isSelected = inboxId => {
  return selectedInboxIds.value.includes(inboxId);
};

// Toggle inbox selection
const toggleInbox = inboxId => {
  // Don't allow selecting inboxes used by other assistants
  if (isUsedByOtherAssistant(inboxId)) {
    return;
  }

  const index = selectedInboxIds.value.indexOf(inboxId);
  if (index === -1) {
    selectedInboxIds.value.push(inboxId);
  } else {
    selectedInboxIds.value.splice(index, 1);
  }
};

// Check if there are changes
const hasChanges = computed(() => {
  if (connectedInboxIds.value.length !== selectedInboxIds.value.length) {
    return true;
  }
  const sorted1 = [...connectedInboxIds.value].sort();
  const sorted2 = [...selectedInboxIds.value].sort();
  return sorted1.some((id, i) => id !== sorted2[i]);
});

// Save changes
const handleSave = async () => {
  if (!hasChanges.value) {
    dialogRef.value.close();
    return;
  }

  isSaving.value = true;
  try {
    // Find inboxes to add and remove
    const toAdd = selectedInboxIds.value.filter(
      id => !connectedInboxIds.value.includes(id)
    );
    const toRemove = connectedInboxIds.value.filter(
      id => !selectedInboxIds.value.includes(id)
    );

    // Add new connections
    for (const inboxId of toAdd) {
      await saturnInboxesAPI.create({
        assistantId: props.assistantId,
        inboxId,
      });
    }

    // Remove disconnected
    for (const inboxId of toRemove) {
      await saturnInboxesAPI.delete({
        assistantId: props.assistantId,
        inboxId,
      });
    }

    useAlert(translations.SAVE_SUCCESS);
    emit('updated');
    dialogRef.value.close();
  } catch (error) {
    console.error('Error saving inbox connections:', error);
    useAlert(translations.SAVE_ERROR);
  } finally {
    isSaving.value = false;
  }
};

const handleClose = () => {
  emit('close');
};

// Initialize
onMounted(() => {
  store.dispatch('inboxes/get');
  fetchConnectedInboxes();
});

defineExpose({ dialogRef });
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="edit"
    :title="translations.TITLE"
    :description="`${assistantName} - ${translations.DESCRIPTION}`"
    :show-cancel-button="false"
    :show-confirm-button="false"
    overflow-y-auto
    @close="handleClose"
  >
    <div class="flex flex-col gap-4 py-2">
      <!-- Loading State -->
      <div v-if="isLoading" class="flex items-center justify-center py-8">
        <i class="i-lucide-loader-2 size-6 animate-spin text-n-slate-11" />
      </div>

      <!-- No Inboxes -->
      <div
        v-else-if="sortedInboxes.length === 0"
        class="flex flex-col items-center justify-center py-8 text-center"
      >
        <i class="i-lucide-inbox size-12 text-n-slate-9 mb-3" />
        <p class="text-sm text-n-slate-11 mb-4">
          {{ translations.NO_INBOXES }}
        </p>
        <Button
          icon="i-lucide-plus"
          :label="translations.ADD_CHANNEL"
          @click="router.push({ name: 'settings_inbox_new' }); dialogRef.close();"
        />
      </div>

      <!-- Inbox List -->
      <div v-else class="flex flex-col gap-2">
        <p class="text-xs text-n-slate-11 mb-2">
          {{ translations.SELECT_HINT }}
        </p>

        <div
          v-for="inbox in sortedInboxes"
          :key="inbox.id"
          class="flex items-center gap-3 p-3 rounded-lg border transition-all"
          :class="[
            isUsedByOtherAssistant(inbox.id)
              ? 'bg-n-slate-3 border-n-slate-5 cursor-not-allowed opacity-60'
              : isSelected(inbox.id)
                ? 'bg-n-blue-3 border-n-blue-7 cursor-pointer'
                : 'bg-n-solid-2 border-n-weak hover:border-n-slate-7 cursor-pointer',
          ]"
          @click="toggleInbox(inbox.id)"
        >
          <div
            class="size-5 rounded flex items-center justify-center border transition-all"
            :class="[
              isUsedByOtherAssistant(inbox.id)
                ? 'bg-n-slate-4 border-n-slate-6'
                : isSelected(inbox.id)
                  ? 'bg-n-blue-9 border-n-blue-9'
                  : 'bg-n-solid-1 border-n-slate-7',
            ]"
          >
            <i
              v-if="isSelected(inbox.id) && !isUsedByOtherAssistant(inbox.id)"
              class="i-lucide-check size-3.5 text-white"
            />
            <i
              v-else-if="isUsedByOtherAssistant(inbox.id)"
              class="i-lucide-lock size-3 text-n-slate-9"
            />
          </div>
          <div class="flex-1 min-w-0">
            <p
              class="text-sm font-medium truncate"
              :class="
                isUsedByOtherAssistant(inbox.id)
                  ? 'text-n-slate-10'
                  : 'text-n-slate-12'
              "
            >
              {{ inbox.name }}
            </p>
            <p class="text-xs text-n-slate-11">
              {{ inbox.channel_type }}
            </p>
          </div>
          <!-- Used by another assistant -->
          <span
            v-if="isUsedByOtherAssistant(inbox.id)"
            class="text-xs px-2 py-0.5 rounded-full bg-n-amber-3 text-n-amber-11 flex items-center gap-1"
          >
            <i class="i-lucide-user size-3" />
            {{ getAssistantUsingInbox(inbox.id) }}
          </span>
          <!-- Connected to current assistant -->
          <span
            v-else-if="connectedInboxIds.includes(inbox.id)"
            class="text-xs px-2 py-0.5 rounded-full bg-n-slate-5 text-n-slate-11"
          >
            {{ translations.CONNECTED }}
          </span>
        </div>
      </div>

      <!-- Selected Count -->
      <div
        v-if="sortedInboxes.length > 0"
        class="flex items-center justify-between pt-2 border-t border-n-weak"
      >
        <span class="text-sm text-n-slate-11">
          {{ selectedInboxIds.length }} {{ translations.SELECTED }}
        </span>
        <div
          v-if="hasChanges"
          class="flex items-center gap-1 text-xs text-n-amber-11"
        >
          <i class="i-lucide-info size-3.5" />
          {{ translations.UNSAVED_CHANGES }}
        </div>
      </div>
    </div>

    <template #footer>
      <div class="flex items-center justify-end gap-3 w-full">
        <Button
          variant="faded"
          color="slate"
          :label="translations.CANCEL"
          @click="dialogRef.close()"
        />
        <Button
          :label="translations.SAVE"
          :is-loading="isSaving"
          :disabled="!hasChanges || isSaving"
          @click="handleSave"
        />
      </div>
    </template>
  </Dialog>
</template>

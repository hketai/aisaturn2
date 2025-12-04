<script setup>
import { reactive, computed, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import { useMapGetter } from 'dashboard/composables/store';
import { useStore } from 'vuex';
import { SATURN_SECTORS } from 'dashboard/constants/saturnSectors';

import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';

const props = defineProps({
  formMode: {
    type: String,
    required: true,
    validator: value => ['modify', 'create'].includes(value),
  },
  assistantData: {
    type: Object,
    default: () => ({}),
  },
  isSubmitting: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['submit', 'cancel']);

const { t } = useI18n();
const store = useStore();
const inboxes = useMapGetter('inboxes/getInboxes');

onMounted(() => {
  store.dispatch('inboxes/get');
});

const defaultFormData = {
  assistantName: '',
  assistantDescription: '',
  sector: '',
  temperature: 0.7,
  selectedInboxIds: [],
};

const formData = reactive({ ...defaultFormData });

const rules = {
  assistantName: { required, minLength: minLength(1) },
  assistantDescription: { required, minLength: minLength(1) },
};

const validator = useVuelidate(rules, formData);

const isSubmitting = computed(() => props.isSubmitting);

const sortedInboxes = computed(() => {
  return inboxes.value?.slice().sort((a, b) => a.name.localeCompare(b.name)) || [];
});

const getFieldError = (field, errorKey) => {
  return validator.value[field].$error
    ? t(`SATURN.ASSISTANTS.FORM.${errorKey}.ERROR`)
    : '';
};

const fieldErrors = computed(() => ({
  assistantName: getFieldError('assistantName', 'NAME'),
  assistantDescription: getFieldError('assistantDescription', 'DESCRIPTION'),
}));

const cancelForm = () => emit('cancel');

const toggleInbox = (inboxId) => {
  const index = formData.selectedInboxIds.indexOf(inboxId);
  if (index === -1) {
    formData.selectedInboxIds.push(inboxId);
  } else {
    formData.selectedInboxIds.splice(index, 1);
  }
};

const isInboxSelected = (inboxId) => {
  return formData.selectedInboxIds.includes(inboxId);
};

const buildAssistantPayload = () => ({
  name: formData.assistantName,
  description: formData.assistantDescription,
  sector: formData.sector || null,
  config: {
    temperature: formData.temperature || 0.7,
  },
  inbox_ids: formData.selectedInboxIds,
});

const submitForm = async () => {
  const isValid = await validator.value.$validate();
  if (!isValid) {
    return;
  }

  emit('submit', buildAssistantPayload());
};

const populateFormFromAssistant = assistant => {
  if (!assistant) return;

  const { name, description, sector, config, connected_inboxes } = assistant;

  Object.assign(formData, {
    assistantName: name,
    assistantDescription: description,
    sector: sector || '',
    temperature: config?.temperature || 0.7,
    selectedInboxIds: connected_inboxes?.map(inbox => inbox.id) || [],
  });
};

watch(
  () => props.assistantData,
  newAssistant => {
    if (props.formMode === 'modify' && newAssistant) {
      populateFormFromAssistant(newAssistant);
    }
  },
  { immediate: true }
);
</script>

<template>
  <form class="flex flex-col h-full" @submit.prevent="submitForm">
    <!-- Form Content -->
    <div class="flex-1 space-y-5 overflow-y-auto pb-4">
      <!-- Asistan Adı -->
      <Input
        v-model="formData.assistantName"
        label="Asistan Adı"
        placeholder="Örn: Satış Asistanı"
        :message="fieldErrors.assistantName"
        :message-type="fieldErrors.assistantName ? 'error' : 'info'"
      />

      <!-- Sektör & Temperature Row -->
      <div class="grid grid-cols-2 gap-4">
        <!-- Sektör -->
        <div class="flex flex-col gap-1.5">
          <label class="text-sm font-medium text-n-slate-12">Sektör</label>
          <select
            v-model="formData.sector"
            class="h-10 px-3 rounded-lg border border-n-weak bg-n-solid-2 text-sm text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-blue-7 focus:border-transparent transition-all"
          >
            <option value="">Seçiniz</option>
            <option v-for="sector in SATURN_SECTORS" :key="sector.value" :value="sector.value">
              {{ sector.label }}
            </option>
          </select>
        </div>

        <!-- Temperature -->
        <div class="flex flex-col gap-1.5">
          <label class="text-sm font-medium text-n-slate-12">
            Yaratıcılık
            <span class="text-n-slate-10 font-normal ml-1">({{ formData.temperature }})</span>
          </label>
          <div class="flex items-center gap-3 h-10">
            <span class="text-xs text-n-slate-10">Tutarlı</span>
            <input
              v-model.number="formData.temperature"
              type="range"
              min="0"
              max="1"
              step="0.1"
              class="flex-1 h-2 bg-n-slate-4 rounded-lg appearance-none cursor-pointer accent-n-blue-9"
            />
            <span class="text-xs text-n-slate-10">Yaratıcı</span>
          </div>
        </div>
      </div>

      <!-- Açıklama -->
      <div class="flex flex-col gap-1.5">
        <label class="text-sm font-medium text-n-slate-12">Açıklama</label>
        <TextArea
          v-model="formData.assistantDescription"
          placeholder="Asistanın ne yapacağını kısaca açıklayın..."
          rows="3"
          :message="fieldErrors.assistantDescription"
          :message-type="fieldErrors.assistantDescription ? 'error' : 'info'"
        />
      </div>

      <!-- Kanal Seçimi -->
      <div v-if="sortedInboxes.length > 0" class="flex flex-col gap-2">
        <label class="text-sm font-medium text-n-slate-12">
          Bağlı Kanallar
          <span v-if="formData.selectedInboxIds.length > 0" class="text-n-blue-11 ml-1">
            ({{ formData.selectedInboxIds.length }})
          </span>
        </label>
        <div class="flex flex-wrap gap-2">
          <button
            v-for="inbox in sortedInboxes"
            :key="inbox.id"
            type="button"
            class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium transition-all"
            :class="isInboxSelected(inbox.id) 
              ? 'bg-n-blue-9 text-white' 
              : 'bg-n-slate-3 text-n-slate-11 hover:bg-n-slate-4'"
            @click="toggleInbox(inbox.id)"
          >
            <i 
              :class="isInboxSelected(inbox.id) ? 'i-lucide-check' : 'i-lucide-plus'" 
              class="size-3"
            />
            {{ inbox.name }}
          </button>
        </div>
      </div>
    </div>

    <!-- Footer Actions -->
    <div class="flex items-center justify-end gap-3 pt-4 border-t border-n-weak mt-auto">
      <Button
        type="button"
        variant="faded"
        color="slate"
        label="İptal"
        @click="cancelForm"
      />
      <Button
        type="submit"
        :label="formMode === 'create' ? 'Oluştur' : 'Kaydet'"
        :is-loading="isSubmitting"
        :disabled="isSubmitting"
      />
    </div>
  </form>
</template>

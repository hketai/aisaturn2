<script setup>
import { reactive, computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import { useMapGetter } from 'dashboard/composables/store';
import saturnInboxesAPI from 'dashboard/api/saturn/inboxes';
import inboxesAPI from 'dashboard/api/inboxes';

import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';

const props = defineProps({
  assistantId: {
    type: Number,
    required: true,
  },
});

const emit = defineEmits(['submit', 'cancel']);

const { t } = useI18n();

const formState = {
  inboxes: useMapGetter('inboxes/getInboxes'),
};

const initialState = {
  inboxId: null,
};

const state = reactive({ ...initialState });

const validationRules = {
  inboxId: { required },
};

const connectedInboxIds = ref([]);
const isFetchingConnected = ref(false);

const fetchConnectedInboxes = async () => {
  isFetchingConnected.value = true;
  try {
    const response = await saturnInboxesAPI.get({
      assistantId: props.assistantId,
    });
    connectedInboxIds.value = (
      Array.isArray(response.data) ? response.data : []
    ).map(i => i.id);
  } catch (error) {
    console.error('Error fetching connected inboxes:', error);
  } finally {
    isFetchingConnected.value = false;
  }
};

const inboxList = computed(() => {
  return formState.inboxes.value
    .filter(inbox => !connectedInboxIds.value.includes(inbox.id))
    .map(inbox => ({
      value: inbox.id,
      label: inbox.name,
    }));
});

const v$ = useVuelidate(validationRules, state);

const getErrorMessage = (field, errorKey) => {
  return v$.value[field].$error
    ? t(`SATURN.INBOXES.FORM.${errorKey}.ERROR`)
    : '';
};

const formErrors = computed(() => ({
  inboxId: getErrorMessage('inboxId', 'INBOX'),
}));

const handleCancel = () => emit('cancel');

const handleSubmit = async () => {
  const isFormValid = await v$.value.$validate();
  if (!isFormValid) {
    return;
  }

  emit('submit', {
    inboxId: state.inboxId,
    assistantId: props.assistantId,
  });
};

onMounted(() => {
  fetchConnectedInboxes();
});
</script>

<template>
  <form class="flex flex-col gap-4" @submit.prevent="handleSubmit">
    <div class="flex flex-col gap-1">
      <label for="inbox" class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ t('SATURN.INBOXES.FORM.INBOX.LABEL') }}
      </label>
      <ComboBox
        id="inbox"
        v-model="state.inboxId"
        :options="inboxList"
        :has-error="!!formErrors.inboxId"
        :placeholder="t('SATURN.INBOXES.FORM.INBOX.PLACEHOLDER')"
        class="[&>div>button]:bg-n-alpha-black2"
        :message="formErrors.inboxId"
      />
    </div>

    <div class="flex items-center justify-between w-full gap-3">
      <Button
        type="button"
        variant="faded"
        color="slate"
        :label="t('SATURN.FORM.CANCEL')"
        class="w-full"
        @click="handleCancel"
      />
      <Button type="submit" :label="t('SATURN.FORM.CREATE')" class="w-full" />
    </div>
  </form>
</template>

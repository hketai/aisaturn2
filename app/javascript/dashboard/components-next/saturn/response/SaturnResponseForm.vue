<script setup>
import { reactive, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';

import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Editor from 'dashboard/components-next/Editor/Editor.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';

const props = defineProps({
  assistants: {
    type: Array,
    default: () => [],
  },
  response: {
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

const initialState = {
  question: '',
  answer: '',
  assistantId: null,
  status: 'approved',
};

const state = reactive({
  ...initialState,
  ...(props.response?.id
    ? {
        question: props.response.question || '',
        answer: props.response.answer || '',
        assistantId: props.response.assistant?.id || null,
        status: props.response.status || 'approved',
      }
    : {}),
});

const validationRules = {
  question: { required, minLength: minLength(1) },
  answer: { required, minLength: minLength(1) },
  assistantId: { required },
};

const assistantList = computed(() =>
  props.assistants.map(assistant => ({
    value: assistant.id,
    label: assistant.name,
  }))
);

const statusOptions = [
  { value: 'pending', label: t('SATURN.RESPONSES.STATUS.PENDING') },
  { value: 'approved', label: t('SATURN.RESPONSES.STATUS.APPROVED') },
];

const v$ = useVuelidate(validationRules, state);

const getErrorMessage = (field, errorKey) => {
  return v$.value[field].$error
    ? t(`SATURN.RESPONSES.FORM.${errorKey}.ERROR`)
    : '';
};

const formErrors = computed(() => ({
  question: getErrorMessage('question', 'QUESTION'),
  answer: getErrorMessage('answer', 'ANSWER'),
  assistantId: getErrorMessage('assistantId', 'ASSISTANT'),
}));

const handleCancel = () => emit('cancel');

const handleSubmit = async () => {
  const isFormValid = await v$.value.$validate();
  if (!isFormValid) {
    return;
  }

  emit('submit', {
    question: state.question,
    answer: state.answer,
    assistant_id: state.assistantId,
    status: state.status,
  });
};
</script>

<template>
  <form class="flex flex-col gap-4" @submit.prevent="handleSubmit">
    <div class="flex flex-col gap-1">
      <label for="assistant" class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ t('SATURN.RESPONSES.FORM.ASSISTANT.LABEL') }}
      </label>
      <ComboBox
        id="assistant"
        v-model="state.assistantId"
        :options="assistantList"
        :has-error="!!formErrors.assistantId"
        :placeholder="t('SATURN.RESPONSES.FORM.ASSISTANT.PLACEHOLDER')"
        class="[&>div>button]:bg-n-alpha-black2"
        :message="formErrors.assistantId"
      />
    </div>

    <Input
      v-model="state.question"
      :label="t('SATURN.RESPONSES.FORM.QUESTION.LABEL')"
      :placeholder="t('SATURN.RESPONSES.FORM.QUESTION.PLACEHOLDER')"
      :message="formErrors.question"
      :message-type="formErrors.question ? 'error' : 'info'"
    />

    <Editor
      v-model="state.answer"
      :label="t('SATURN.RESPONSES.FORM.ANSWER.LABEL')"
      :placeholder="t('SATURN.RESPONSES.FORM.ANSWER.PLACEHOLDER')"
      :message="formErrors.answer"
      :message-type="formErrors.answer ? 'error' : 'info'"
    />

    <div class="flex flex-col gap-1">
      <label for="status" class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ t('SATURN.RESPONSES.FORM.STATUS.LABEL') }}
      </label>
      <ComboBox
        id="status"
        v-model="state.status"
        :options="statusOptions"
        class="[&>div>button]:bg-n-alpha-black2"
      />
    </div>

    <div class="flex gap-3 justify-between items-center w-full">
      <Button
        type="button"
        variant="faded"
        color="slate"
        :label="t('SATURN.FORM.CANCEL')"
        class="w-full"
        @click="handleCancel"
      />
      <Button
        type="submit"
        :label="t('SATURN.FORM.CREATE')"
        class="w-full"
        :is-loading="isSubmitting"
        :disabled="isSubmitting"
      />
    </div>
  </form>
</template>

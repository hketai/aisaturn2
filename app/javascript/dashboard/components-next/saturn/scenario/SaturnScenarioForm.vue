<script setup>
import { reactive, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import saturnScenariosAPI from 'dashboard/api/saturn/scenarios';
import { useAlert } from 'dashboard/composables';

import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Editor from 'dashboard/components-next/Editor/Editor.vue';

const props = defineProps({
  assistantId: {
    type: Number,
    required: true,
  },
  scenario: {
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
  title: '',
  description: '',
  instruction: '',
  enabled: true,
};

const state = reactive({
  ...initialState,
  ...(props.scenario?.id
    ? {
        title: props.scenario.title || '',
        description: props.scenario.description || '',
        instruction: props.scenario.instruction || '',
        enabled: props.scenario.enabled ?? true,
      }
    : {}),
});

const validationRules = {
  title: { required, minLength: minLength(1) },
  description: { required },
  instruction: { required },
};

const v$ = useVuelidate(validationRules, state);

const getErrorMessage = (field, errorKey) => {
  return v$.value[field].$error
    ? t(`SATURN.SCENARIOS.FORM.${errorKey}.ERROR`)
    : '';
};

const formErrors = computed(() => ({
  title: getErrorMessage('title', 'TITLE'),
  description: getErrorMessage('description', 'DESCRIPTION'),
  instruction: getErrorMessage('instruction', 'INSTRUCTION'),
}));

const handleCancel = () => emit('cancel');

const handleSubmit = async () => {
  const isValid = await v$.value.$validate();
  if (!isValid) return;

  try {
    await saturnScenariosAPI.create({
      assistantId: props.assistantId,
      scenario: state,
    });
    useAlert(t('SATURN.SCENARIOS.CREATE.SUCCESS_MESSAGE'));
    emit('submit');
  } catch (error) {
    useAlert(error?.message || t('SATURN.SCENARIOS.CREATE.ERROR_MESSAGE'));
  }
};
</script>

<template>
  <form class="flex flex-col gap-4" @submit.prevent="handleSubmit">
    <Input
      v-model="state.title"
      :label="$t('SATURN.SCENARIOS.FORM.TITLE.LABEL')"
      :placeholder="$t('SATURN.SCENARIOS.FORM.TITLE.PLACEHOLDER')"
      :message="formErrors.title"
      :message-type="formErrors.title ? 'error' : 'info'"
    />

    <TextArea
      v-model="state.description"
      :label="$t('SATURN.SCENARIOS.FORM.DESCRIPTION.LABEL')"
      :placeholder="$t('SATURN.SCENARIOS.FORM.DESCRIPTION.PLACEHOLDER')"
      :message="formErrors.description"
      :message-type="formErrors.description ? 'error' : 'info'"
    />

    <Editor
      v-model="state.instruction"
      :label="$t('SATURN.SCENARIOS.FORM.INSTRUCTION.LABEL')"
      :placeholder="$t('SATURN.SCENARIOS.FORM.INSTRUCTION.PLACEHOLDER')"
      :message="formErrors.instruction"
      :message-type="formErrors.instruction ? 'error' : 'info'"
    />

    <div class="flex items-center gap-3">
      <Button
        type="button"
        variant="faded"
        color="slate"
        :label="$t('SATURN.FORM.CANCEL')"
        class="w-full"
        @click="handleCancel"
      />
      <Button
        type="submit"
        :label="$t('SATURN.FORM.CREATE')"
        class="w-full"
        :is-loading="isSubmitting"
        :disabled="isSubmitting"
      />
    </div>
  </form>
</template>

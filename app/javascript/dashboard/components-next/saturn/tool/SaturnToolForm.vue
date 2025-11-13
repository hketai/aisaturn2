<script setup>
import { reactive, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import saturnToolsAPI from 'dashboard/api/saturn/customTools';
import { useAlert } from 'dashboard/composables';

import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';

const props = defineProps({
  tool: {
    type: Object,
    default: () => ({}),
  },
  formMode: {
    type: String,
    default: 'create',
    validator: value => ['create', 'edit'].includes(value),
  },
  isSubmitting: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['submit', 'cancel']);

const { t } = useI18n();

const initialState = {
  slug: '',
  title: '',
  description: '',
  httpMethod: 'GET',
  endpointUrl: '',
  authType: 'none',
  enabled: true,
};

const state = reactive({
  ...initialState,
  ...(props.tool?.id
    ? {
        slug: props.tool.slug || '',
        title: props.tool.title || '',
        description: props.tool.description || '',
        httpMethod: props.tool.http_method || 'GET',
        endpointUrl: props.tool.endpoint_url || '',
        authType: props.tool.auth_type || 'none',
        enabled: props.tool.enabled ?? true,
      }
    : {}),
});

const validationRules = {
  slug: { required, minLength: minLength(1) },
  title: { required, minLength: minLength(1) },
  endpointUrl: { required, minLength: minLength(1) },
  httpMethod: { required },
};

const httpMethodOptions = [
  { value: 'GET', label: 'GET' },
  { value: 'POST', label: 'POST' },
  { value: 'PUT', label: 'PUT' },
  { value: 'PATCH', label: 'PATCH' },
  { value: 'DELETE', label: 'DELETE' },
];

const authTypeOptions = [
  { value: 'none', label: t('SATURN.TOOLS.FORM.AUTH_TYPES.NONE') },
  { value: 'bearer', label: t('SATURN.TOOLS.FORM.AUTH_TYPES.BEARER') },
  { value: 'api_key', label: t('SATURN.TOOLS.FORM.AUTH_TYPES.API_KEY') },
];

const v$ = useVuelidate(validationRules, state);

const getErrorMessage = (field, errorKey) => {
  return v$.value[field].$error ? t(`SATURN.TOOLS.FORM.${errorKey}.ERROR`) : '';
};

const formErrors = computed(() => ({
  slug: getErrorMessage('slug', 'SLUG'),
  title: getErrorMessage('title', 'TITLE'),
  endpointUrl: getErrorMessage('endpointUrl', 'ENDPOINT_URL'),
}));

const handleCancel = () => emit('cancel');

const handleSubmit = async () => {
  const isValid = await v$.value.$validate();
  if (!isValid) return;

  try {
    const toolData = {
      slug: state.slug,
      title: state.title,
      description: state.description,
      http_method: state.httpMethod,
      endpoint_url: state.endpointUrl,
      auth_type: state.authType,
      enabled: state.enabled,
    };

    if (props.formMode === 'edit') {
      await saturnToolsAPI.update(props.tool.id, toolData);
      useAlert(t('SATURN.TOOLS.EDIT.SUCCESS_MESSAGE'));
    } else {
      await saturnToolsAPI.create(toolData);
      useAlert(t('SATURN.TOOLS.CREATE.SUCCESS_MESSAGE'));
    }
    emit('submit');
  } catch (error) {
    useAlert(
      error?.message ||
        t(`SATURN.TOOLS.${props.formMode.toUpperCase()}.ERROR_MESSAGE`)
    );
  }
};
</script>

<template>
  <form class="flex flex-col gap-4" @submit.prevent="handleSubmit">
    <Input
      v-model="state.slug"
      :label="$t('SATURN.TOOLS.FORM.SLUG.LABEL')"
      :placeholder="$t('SATURN.TOOLS.FORM.SLUG.PLACEHOLDER')"
      :message="formErrors.slug"
      :message-type="formErrors.slug ? 'error' : 'info'"
    />

    <Input
      v-model="state.title"
      :label="$t('SATURN.TOOLS.FORM.TITLE.LABEL')"
      :placeholder="$t('SATURN.TOOLS.FORM.TITLE.PLACEHOLDER')"
      :message="formErrors.title"
      :message-type="formErrors.title ? 'error' : 'info'"
    />

    <TextArea
      v-model="state.description"
      :label="$t('SATURN.TOOLS.FORM.DESCRIPTION.LABEL')"
      :placeholder="$t('SATURN.TOOLS.FORM.DESCRIPTION.PLACEHOLDER')"
    />

    <div class="flex gap-4">
      <div class="flex-1">
        <label class="mb-0.5 text-sm font-medium text-n-slate-12">
          {{ $t('SATURN.TOOLS.FORM.HTTP_METHOD.LABEL') }}
        </label>
        <ComboBox
          v-model="state.httpMethod"
          :options="httpMethodOptions"
          class="[&>div>button]:bg-n-alpha-black2"
        />
      </div>
      <div class="flex-1">
        <label class="mb-0.5 text-sm font-medium text-n-slate-12">
          {{ $t('SATURN.TOOLS.FORM.AUTH_TYPE.LABEL') }}
        </label>
        <ComboBox
          v-model="state.authType"
          :options="authTypeOptions"
          class="[&>div>button]:bg-n-alpha-black2"
        />
      </div>
    </div>

    <Input
      v-model="state.endpointUrl"
      :label="$t('SATURN.TOOLS.FORM.ENDPOINT_URL.LABEL')"
      :placeholder="$t('SATURN.TOOLS.FORM.ENDPOINT_URL.PLACEHOLDER')"
      :message="formErrors.endpointUrl"
      :message-type="formErrors.endpointUrl ? 'error' : 'info'"
    />

    <label class="flex items-center gap-2 cursor-pointer">
      <input
        v-model="state.enabled"
        type="checkbox"
        class="w-4 h-4 rounded border-slate-300 text-blue-600"
      />
      <span class="text-sm text-n-slate-12">
        {{ $t('SATURN.TOOLS.FORM.ENABLED.LABEL') }}
      </span>
    </label>

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
        :label="$t(`SATURN.FORM.${formMode.toUpperCase()}`)"
        class="w-full"
        :is-loading="isSubmitting"
        :disabled="isSubmitting"
      />
    </div>
  </form>
</template>

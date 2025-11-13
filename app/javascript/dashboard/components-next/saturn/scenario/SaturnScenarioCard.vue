<script setup>
import { computed, reactive, ref } from 'vue';
import { useToggle } from '@vueuse/core';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import { usePolicy } from 'dashboard/composables/usePolicy';

import CardLayout from 'dashboard/components-next/CardLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Editor from 'dashboard/components-next/Editor/Editor.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';

const props = defineProps({
  id: {
    type: Number,
    required: true,
  },
  title: {
    type: String,
    required: true,
  },
  description: {
    type: String,
    required: true,
  },
  instruction: {
    type: String,
    required: true,
  },
  enabled: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['update', 'delete', 'toggle']);

const { checkPermissions } = usePolicy();
const { t } = useI18n();

const [isEditing, toggleEditing] = useToggle();

const state = reactive({
  title: props.title,
  description: props.description,
  instruction: props.instruction,
  enabled: props.enabled,
});

const rules = {
  title: { required, minLength: minLength(1) },
  description: { required },
  instruction: { required },
};

const v$ = useVuelidate(rules, state);

const startEdit = () => {
  Object.assign(state, {
    title: props.title,
    description: props.description,
    instruction: props.instruction,
    enabled: props.enabled,
  });
  toggleEditing(true);
};

const handleUpdate = async () => {
  const isValid = await v$.value.$validate();
  if (!isValid) return;

  emit('update', {
    id: props.id,
    ...state,
  });
  toggleEditing(false);
};

const handleToggle = () => {
  emit('toggle', { id: props.id, enabled: !props.enabled });
};
</script>

<template>
  <CardLayout>
    <div v-if="!isEditing" class="flex flex-col gap-3">
      <div class="flex items-start justify-between gap-2">
        <div class="flex-1">
          <div class="flex items-center gap-2 mb-1">
            <h3 class="text-base font-medium text-n-slate-12">{{ title }}</h3>
            <label class="flex items-center gap-2 cursor-pointer">
              <input
                type="checkbox"
                :checked="enabled"
                class="w-4 h-4 rounded border-slate-300 text-blue-600"
                @change="handleToggle"
              />
              <span class="text-xs text-n-slate-11">
                {{ enabled ? 'Enabled' : 'Disabled' }}
              </span>
            </label>
          </div>
          <p class="text-sm text-n-slate-11">{{ description }}</p>
        </div>
        <div class="flex items-center gap-2">
          <Button
            icon="i-lucide-pencil"
            color="slate"
            size="xs"
            variant="ghost"
            @click="startEdit"
          />
          <Button
            icon="i-lucide-trash"
            color="ruby"
            size="xs"
            variant="ghost"
            @click="emit('delete', id)"
          />
        </div>
      </div>
      <div class="text-sm text-n-slate-12 prose prose-sm max-w-none">
        <div v-html="instruction" />
      </div>
    </div>
    <div v-else class="flex flex-col gap-4">
      <Input
        v-model="state.title"
        :label="$t('SATURN.SCENARIOS.FORM.TITLE.LABEL')"
        :placeholder="$t('SATURN.SCENARIOS.FORM.TITLE.PLACEHOLDER')"
        :message="
          v$.title.$error ? $t('SATURN.SCENARIOS.FORM.TITLE.ERROR') : ''
        "
        :message-type="v$.title.$error ? 'error' : 'info'"
      />
      <TextArea
        v-model="state.description"
        :label="$t('SATURN.SCENARIOS.FORM.DESCRIPTION.LABEL')"
        :placeholder="$t('SATURN.SCENARIOS.FORM.DESCRIPTION.PLACEHOLDER')"
        :message="
          v$.description.$error
            ? $t('SATURN.SCENARIOS.FORM.DESCRIPTION.ERROR')
            : ''
        "
        :message-type="v$.description.$error ? 'error' : 'info'"
      />
      <Editor
        v-model="state.instruction"
        :label="$t('SATURN.SCENARIOS.FORM.INSTRUCTION.LABEL')"
        :placeholder="$t('SATURN.SCENARIOS.FORM.INSTRUCTION.PLACEHOLDER')"
        :message="
          v$.instruction.$error
            ? $t('SATURN.SCENARIOS.FORM.INSTRUCTION.ERROR')
            : ''
        "
        :message-type="v$.instruction.$error ? 'error' : 'info'"
      />
      <div class="flex items-center gap-3">
        <Button
          variant="faded"
          color="slate"
          size="sm"
          :label="$t('SATURN.FORM.CANCEL')"
          @click="toggleEditing(false)"
        />
        <Button
          size="sm"
          :label="$t('SATURN.SCENARIOS.UPDATE')"
          @click="handleUpdate"
        />
      </div>
    </div>
  </CardLayout>
</template>

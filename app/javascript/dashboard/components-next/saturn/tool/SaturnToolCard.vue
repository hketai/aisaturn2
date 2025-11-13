<script setup>
import { computed } from 'vue';
import { useToggle } from '@vueuse/core';
import { useI18n } from 'vue-i18n';
import { dynamicTime } from 'shared/helpers/timeHelper';
import { usePolicy } from 'dashboard/composables/usePolicy';

import CardLayout from 'dashboard/components-next/CardLayout.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import Button from 'dashboard/components-next/button/Button.vue';

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
    default: '',
  },
  endpointUrl: {
    type: String,
    required: true,
  },
  httpMethod: {
    type: String,
    required: true,
  },
  enabled: {
    type: Boolean,
    default: false,
  },
  createdAt: {
    type: Number,
    required: true,
  },
});

const emit = defineEmits(['action']);

const { checkPermissions } = usePolicy();
const { t } = useI18n();

const [showActionsDropdown, toggleDropdown] = useToggle();

const menuItems = computed(() => {
  const allOptions = [];

  if (checkPermissions(['administrator'])) {
    allOptions.push(
      {
        label: t('SATURN.TOOLS.OPTIONS.EDIT_TOOL'),
        value: 'edit',
        action: 'edit',
        icon: 'i-lucide-pencil-line',
      },
      {
        label: t('SATURN.TOOLS.OPTIONS.DELETE_TOOL'),
        value: 'delete',
        action: 'delete',
        icon: 'i-lucide-trash',
      }
    );
  }

  return allOptions;
});

const createdAt = computed(() => dynamicTime(props.createdAt));

const handleAction = ({ action, value }) => {
  toggleDropdown(false);
  emit('action', { action, value, id: props.id });
};
</script>

<template>
  <CardLayout>
    <div class="flex gap-1 justify-between w-full">
      <div class="flex-1">
        <div class="flex items-center gap-2 mb-1">
          <h3 class="text-base font-medium text-n-slate-12">{{ title }}</h3>
          <span
            v-if="enabled"
            class="px-2 py-0.5 text-xs font-medium rounded-md bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200"
          >
            {{ $t('SATURN.TOOLS.STATUS.ENABLED') }}
          </span>
        </div>
        <p class="text-sm text-n-slate-11 mb-2">{{ description }}</p>
        <div class="flex items-center gap-2 text-xs text-n-slate-11">
          <span class="px-2 py-0.5 rounded bg-n-slate-3 font-mono">
            {{ httpMethod }}
          </span>
          <span class="truncate">{{ endpointUrl }}</span>
        </div>
      </div>
      <div class="flex gap-2 items-center">
        <div
          v-on-clickaway="() => toggleDropdown(false)"
          class="flex relative items-center group"
        >
          <Button
            icon="i-lucide-ellipsis-vertical"
            color="slate"
            size="xs"
            variant="ghost"
            class="rounded-md"
            @click="toggleDropdown()"
          />
          <DropdownMenu
            v-if="showActionsDropdown"
            :menu-items="menuItems"
            class="top-full mt-1 ltr:right-0 rtl:left-0"
            @action="handleAction($event)"
          />
        </div>
      </div>
    </div>
    <div class="text-xs text-n-slate-11 mt-2">
      {{ createdAt }}
    </div>
  </CardLayout>
</template>

<script setup>
import { computed } from 'vue';
import { useToggle } from '@vueuse/core';
import { useI18n } from 'vue-i18n';
import { dynamicTime } from 'shared/helpers/timeHelper';
import { usePolicy } from 'dashboard/composables/usePolicy';

import CardLayout from 'dashboard/components-next/CardLayout.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import SaturnIcon from 'dashboard/components-next/icon/SaturnIcon.vue';

const props = defineProps({
  id: {
    type: Number,
    required: true,
  },
  question: {
    type: String,
    required: true,
  },
  answer: {
    type: String,
    required: true,
  },
  status: {
    type: String,
    default: 'approved',
  },
  assistant: {
    type: Object,
    default: () => ({}),
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

  if (props.status === 'pending' && checkPermissions(['administrator'])) {
    allOptions.push({
      label: t('SATURN.RESPONSES.OPTIONS.APPROVE'),
      value: 'approve',
      action: 'approve',
      icon: 'i-lucide-circle-check-big',
    });
  }

  if (checkPermissions(['administrator'])) {
    allOptions.push(
      {
        label: t('SATURN.RESPONSES.OPTIONS.EDIT_RESPONSE'),
        value: 'edit',
        action: 'edit',
        icon: 'i-lucide-pencil-line',
      },
      {
        label: t('SATURN.RESPONSES.OPTIONS.DELETE_RESPONSE'),
        value: 'delete',
        action: 'delete',
        icon: 'i-lucide-trash',
      }
    );
  }

  return allOptions;
});

const createdAt = computed(() => dynamicTime(props.createdAt));
const statusBadge = computed(() => {
  if (props.status === 'pending') {
    return { label: t('SATURN.RESPONSES.STATUS.PENDING'), color: 'amber' };
  }
  return { label: t('SATURN.RESPONSES.STATUS.APPROVED'), color: 'green' };
});

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
          <span class="text-base font-medium text-n-slate-12 line-clamp-1">
            {{ question }}
          </span>
          <span
            v-if="statusBadge"
            class="px-2 py-0.5 text-xs font-medium rounded-md"
            :class="`bg-${statusBadge.color}-100 text-${statusBadge.color}-800 dark:bg-${statusBadge.color}-900 dark:text-${statusBadge.color}-200`"
          >
            {{ statusBadge.label }}
          </span>
        </div>
        <p class="text-sm text-n-slate-11 line-clamp-2">
          {{ answer }}
        </p>
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
    <div class="flex gap-4 justify-between items-center w-full mt-2">
      <span
        class="flex gap-1 items-center text-sm truncate shrink-0 text-n-slate-11"
      >
        <SaturnIcon class="size-4" />
        {{ assistant?.name || '' }}
      </span>
      <div class="text-sm shrink-0 text-n-slate-11 line-clamp-1">
        {{ createdAt }}
      </div>
    </div>
  </CardLayout>
</template>

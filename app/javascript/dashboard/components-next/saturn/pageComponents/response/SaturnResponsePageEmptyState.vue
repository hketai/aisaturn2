<script setup>
import Button from 'dashboard/components-next/button/Button.vue';

const emit = defineEmits(['click']);

const onClick = () => {
  emit('click');
};
</script>

<template>
  <div class="flex flex-col items-center justify-center py-16">
    <h2 class="text-xl font-medium text-n-slate-12 mb-2">
      {{ $t('SATURN.RESPONSES.EMPTY_STATE.TITLE') }}
    </h2>
    <p class="text-sm text-n-slate-11 mb-6 text-center max-w-md">
      {{ $t('SATURN.RESPONSES.EMPTY_STATE.SUBTITLE') }}
    </p>
    <Button
      :label="$t('SATURN.RESPONSES.ADD_NEW')"
      icon="i-lucide-plus"
      @click="onClick"
    />
  </div>
</template>

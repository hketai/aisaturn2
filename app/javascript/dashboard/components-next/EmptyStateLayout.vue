<script setup>
import Policy from 'dashboard/components/policy.vue';

defineProps({
  title: {
    type: String,
    required: true,
  },
  subtitle: {
    type: String,
    required: true,
  },
  actionPerms: {
    type: Array,
    default: () => [],
  },
});
</script>

<template>
  <section
    class="relative flex flex-col items-center justify-center w-full h-full"
  >
    <div class="flex flex-col items-center justify-center gap-6 p-8">
      <div class="flex flex-col items-center justify-center gap-3">
        <h2
          class="text-2xl font-medium text-center text-n-slate-12"
        >
          {{ title }}
        </h2>
        <p
          class="max-w-xl text-base text-center text-n-slate-11"
        >
          {{ subtitle }}
        </p>
      </div>
      <Policy :permissions="actionPerms">
        <slot name="actions" />
      </Policy>
    </div>
  </section>
</template>

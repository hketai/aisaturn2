<script setup>
import { computed } from 'vue';

const props = defineProps({
  messages: {
    type: Array,
    default: () => [],
  },
  isLoading: {
    type: Boolean,
    default: false,
  },
});

const messageGroups = computed(() => {
  const groups = [];
  let currentGroup = null;

  props.messages.forEach(message => {
    if (
      !currentGroup ||
      currentGroup.sender !== message.sender ||
      currentGroup.messages.length >= 3
    ) {
      currentGroup = {
        sender: message.sender,
        messages: [message],
      };
      groups.push(currentGroup);
    } else {
      currentGroup.messages.push(message);
    }
  });

  return groups;
});
</script>

<template>
  <div class="flex-1 overflow-y-auto mb-4 space-y-4">
    <div
      v-for="(group, groupIndex) in messageGroups"
      :key="groupIndex"
      class="flex"
      :class="group.sender === 'user' ? 'justify-end' : 'justify-start'"
    >
      <div
        class="max-w-[80%] rounded-lg p-3"
        :class="
          group.sender === 'user'
            ? 'bg-n-blue-9 text-white'
            : group.sender === 'error'
              ? 'bg-n-red-3 text-n-red-11 border border-n-red-6'
              : 'bg-n-slate-3 text-n-slate-12'
        "
      >
        <div
          v-for="(message, msgIndex) in group.messages"
          :key="msgIndex"
          class="text-sm"
          :class="msgIndex > 0 ? 'mt-2' : ''"
        >
          {{ message.content }}
        </div>
      </div>
    </div>

    <div v-if="isLoading" class="flex justify-start">
      <div class="max-w-[80%] rounded-lg p-3 bg-n-slate-3 text-n-slate-12">
        <div class="flex items-center gap-2">
          <div class="w-2 h-2 rounded-full bg-n-slate-11 animate-pulse" />
          <div
            class="w-2 h-2 rounded-full bg-n-slate-11 animate-pulse delay-75"
          />
          <div
            class="w-2 h-2 rounded-full bg-n-slate-11 animate-pulse delay-150"
          />
        </div>
      </div>
    </div>
  </div>
</template>

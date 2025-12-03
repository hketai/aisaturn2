<script setup>
import { computed } from 'vue';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import wootConstants from 'dashboard/constants/globals';

const props = defineProps({
  items: {
    type: Array,
    default: () => [],
  },
  activeTab: {
    type: String,
    default: wootConstants.ASSIGNEE_TYPE.ME,
  },
});

const emit = defineEmits(['chatTabChange']);

const activeTabIndex = computed(() => {
  return props.items.findIndex(item => item.key === props.activeTab);
});

const onTabChange = selectedTabIndex => {
  if (selectedTabIndex >= 0 && selectedTabIndex < props.items.length) {
    const selectedItem = props.items[selectedTabIndex];
    if (selectedItem.key !== props.activeTab) {
      emit('chatTabChange', selectedItem.key);
    }
  }
};

const keyboardEvents = {
  'Alt+KeyN': {
    action: () => {
      if (props.activeTab === wootConstants.ASSIGNEE_TYPE.ALL) {
        onTabChange(0);
      } else {
        const nextIndex = (activeTabIndex.value + 1) % props.items.length;
        onTabChange(nextIndex);
      }
    },
  },
};

useKeyboardEvents(keyboardEvents);
</script>

<template>
  <div class="flex items-center gap-2 px-3 py-2 overflow-x-auto scrollbar-hide">
    <button
      v-for="(item, index) in items"
      :key="item.key"
      class="flex items-center gap-1.5 px-3 py-1.5 rounded-full text-sm font-medium whitespace-nowrap transition-all duration-200 ease-out focus:outline-none focus:ring-2 focus:ring-n-teal-9/50"
      :class="[
        activeTabIndex === index
          ? 'bg-n-teal-9 text-white shadow-sm'
          : 'bg-n-slate-3 text-n-slate-11 hover:bg-n-slate-4 hover:text-n-slate-12',
      ]"
      @click="onTabChange(index)"
    >
      <span>{{ item.name }}</span>
      <span
        v-if="item.count > 0"
        class="text-xs font-semibold"
        :class="[activeTabIndex === index ? 'text-white/80' : 'text-n-slate-10']"
      >
        {{ item.count }}
      </span>
    </button>
  </div>
</template>

<style scoped>
.scrollbar-hide {
  -ms-overflow-style: none;
  scrollbar-width: none;
}
.scrollbar-hide::-webkit-scrollbar {
  display: none;
}
</style>

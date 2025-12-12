<script setup>
const props = defineProps({
  class: {
    type: String,
    default: 'size-4',
  },
  style: {
    type: Object,
    default: null,
  },
});
</script>

<template>
  <svg
    :class="props.class"
    :style="props.style"
    viewBox="0 0 24 24"
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
  >
    <!-- Saturn planet with rings -->
    <circle
      cx="12"
      cy="12"
      r="5"
      stroke="currentColor"
      stroke-width="1.5"
      fill="none"
    />
    <!-- Rings -->
    <ellipse
      cx="12"
      cy="12"
      rx="7"
      ry="2.5"
      stroke="currentColor"
      stroke-width="1.5"
      fill="none"
      opacity="0.6"
    />
    <ellipse
      cx="12"
      cy="12"
      rx="8.5"
      ry="3"
      stroke="currentColor"
      stroke-width="1.5"
      fill="none"
      opacity="0.4"
    />
  </svg>
</template>

<script setup>
defineProps({
  size: {
    type: Number,
    default: 24,
  },
});
</script>

<template>
  <div class="aisa-spinner" :style="{ width: `${size}px`, height: `${size}px` }">
    <div class="aisa-spinner-circle" />
  </div>
</template>

<style>
.aisa-spinner {
  display: flex;
  align-items: center;
  justify-content: center;
  position: relative;
}

.aisa-spinner-circle {
  width: 60%;
  height: 60%;
  border-radius: 50%;
  background-color: #2781F6;
  animation: aisa-pulse 1.4s ease-in-out infinite;
}

@keyframes aisa-pulse {
  0% {
    transform: scale(0.6);
    opacity: 0.3;
  }
  50% {
    transform: scale(1);
    opacity: 0.8;
  }
  100% {
    transform: scale(0.6);
    opacity: 0.3;
  }
}
</style>

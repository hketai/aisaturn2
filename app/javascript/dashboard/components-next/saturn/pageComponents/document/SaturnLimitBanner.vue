<script setup>
import { onMounted, computed, ref } from 'vue';
import { useAccount } from 'dashboard/composables/useAccount';
import { useRouter } from 'vue-router';

import Banner from 'dashboard/components-next/banner/Banner.vue';

const router = useRouter();
const { accountId } = useAccount();

const documentLimits = ref(null);
const isLoading = ref(false);

const fetchLimits = async () => {
  try {
    isLoading.value = true;
    // TODO: Implement Saturn limits API call
    // For now, using a simple check
    documentLimits.value = {
      currentAvailable: 50,
    };
  } catch (error) {
    console.error('Error fetching Saturn limits:', error);
  } finally {
    isLoading.value = false;
  }
};

const openBilling = () => {
  router.push({
    name: 'billing_settings_index',
    params: { accountId: accountId.value },
  });
};

const showBanner = computed(() => {
  if (!documentLimits.value) return false;

  const { currentAvailable } = documentLimits.value;
  return currentAvailable === 0;
});

onMounted(fetchLimits);
</script>

<template>
  <Banner
    v-show="showBanner"
    color="amber"
    :action-label="$t('SATURN.PAYWALL.UPGRADE_NOW')"
    @action="openBilling"
  >
    {{ $t('SATURN.BANNER.DOCUMENTS') }}
  </Banner>
</template>

<script setup>
import { onMounted, computed, ref } from 'vue';
import { useAccount } from 'dashboard/composables/useAccount';
import { useRouter } from 'vue-router';

import Banner from 'dashboard/components-next/banner/Banner.vue';

const router = useRouter();
const { accountId } = useAccount();

const quotaData = ref(null);
const isLoading = ref(false);

const fetchQuotaInfo = async () => {
  try {
    isLoading.value = true;
    // TODO: Implement Saturn quota API call
    // const response = await saturnQuotaAPI.get();
    // quotaData.value = response.data;
  } catch (error) {
    console.error('Error fetching Saturn quota:', error);
  } finally {
    isLoading.value = false;
  }
};

const navigateToBilling = () => {
  router.push({
    name: 'billing_settings_index',
    params: { accountId: accountId.value },
  });
};

const shouldDisplayBanner = computed(() => {
  if (!quotaData.value) return false;

  const { used, limit } = quotaData.value;
  if (!used || !limit) return false;

  return used / limit > 0.8;
});

onMounted(fetchQuotaInfo);
</script>

<template>
  <Banner
    v-show="shouldDisplayBanner"
    color="amber"
    :action-label="$t('SATURN.PAYWALL.UPGRADE_NOW')"
    @action="navigateToBilling"
  >
    {{ $t('SATURN.BANNER.RESPONSES') }}
  </Banner>
</template>

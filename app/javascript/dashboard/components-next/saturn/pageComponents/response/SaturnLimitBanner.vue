<script setup>
import { onMounted, computed, ref } from 'vue';
import { useAccount } from 'dashboard/composables/useAccount';
import { useRouter } from 'vue-router';

import Banner from 'dashboard/components-next/banner/Banner.vue';

const router = useRouter();
const { accountId } = useAccount();

const responseLimits = ref(null);
const isLoading = ref(false);

const fetchLimits = async () => {
  try {
    isLoading.value = true;
    // TODO: Implement Saturn limits API call
    // For now, using a simple check
    responseLimits.value = {
      consumed: 0,
      totalCount: 100,
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
  if (!responseLimits.value) return false;

  const { consumed, totalCount } = responseLimits.value;
  if (!consumed || !totalCount) return false;

  return consumed / totalCount > 0.8;
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
    {{ $t('SATURN.BANNER.RESPONSES') }}
  </Banner>
</template>

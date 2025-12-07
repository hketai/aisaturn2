<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { debounce } from '@chatwoot/utils';
import { useAccount } from 'dashboard/composables/useAccount';
import SaturnPageLayout from 'dashboard/components-next/saturn/SaturnPageLayout.vue';
import shopifyAPI from 'dashboard/api/integrations/shopify';
import Input from 'dashboard/components-next/input/Input.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const { t } = useI18n();
const router = useRouter();
const { accountScopedRoute } = useAccount();

const products = ref([]);
const isFetching = ref(false);
const searchQuery = ref('');
const perPage = ref(20);
const isShopifyConnected = ref(false);
const isCheckingConnection = ref(true);

const isEmpty = computed(() => {
  return (
    !isFetching.value && products.value.length === 0 && isShopifyConnected.value
  );
});

const checkShopifyConnection = async () => {
  isCheckingConnection.value = true;
  try {
    const response = await shopifyAPI.getHook();
    const hookData = response.data?.hook || response.hook;
    isShopifyConnected.value = !!(
      hookData &&
      (hookData.id || hookData.reference_id)
    );
  } catch {
    isShopifyConnected.value = false;
  } finally {
    isCheckingConnection.value = false;
  }
};

const fetchProducts = async () => {
  if (!isShopifyConnected.value) return;

  isFetching.value = true;
  try {
    const response = await shopifyAPI.getProducts(
      searchQuery.value,
      perPage.value
    );
    products.value = response.data?.products || [];
  } catch {
    products.value = [];
  } finally {
    isFetching.value = false;
  }
};

const debouncedSearch = debounce(() => {
  fetchProducts();
}, 300);

watch(searchQuery, () => {
  debouncedSearch();
});

const goToIntegrations = () => {
  router.push(accountScopedRoute('saturn_integrations_index'));
};

onMounted(async () => {
  await checkShopifyConnection();
  if (isShopifyConnected.value) {
    fetchProducts();
  }
});

const formatPrice = (min, max) => {
  if (!min && !max) return '-';
  if (min === max) return `₺${min}`;
  return `₺${min} - ₺${max}`;
};

const getProductImage = product => {
  if (product.images && product.images.length > 0) {
    return product.images[0]?.src || product.images[0];
  }
  return null;
};

const getInventoryStatus = inventory => {
  if (inventory === null || inventory === undefined) return 'unknown';
  if (inventory <= 0) return 'out';
  if (inventory < 10) return 'low';
  return 'in';
};

const getInventoryClass = inventory => {
  const status = getInventoryStatus(inventory);
  return {
    unknown: 'text-n-slate-11',
    out: 'text-n-ruby-11',
    low: 'text-n-amber-11',
    in: 'text-n-teal-11',
  }[status];
};

const formatInventory = inventory => {
  if (inventory === null || inventory === undefined) return '-';
  return `${inventory} ${t('SIDEBAR.SATURN_PRODUCTS_ITEMS')}`;
};
</script>

<template>
  <SaturnPageLayout
    :title="t('SIDEBAR.SATURN_PRODUCTS')"
    :description="t('SIDEBAR.SATURN_PRODUCTS_DESCRIPTION')"
  >
    <!-- Search -->
    <div v-if="isShopifyConnected && !isCheckingConnection" class="mb-6">
      <Input
        v-model="searchQuery"
        :placeholder="t('SIDEBAR.SATURN_PRODUCTS_SEARCH')"
        class="max-w-md"
      >
        <template #prefix>
          <Icon icon="i-lucide-search" class="size-4 text-n-slate-11" />
        </template>
      </Input>
    </div>

    <!-- Loading State -->
    <div
      v-if="isCheckingConnection || isFetching"
      class="flex items-center justify-center py-20"
    >
      <div class="flex flex-col items-center gap-3">
        <Icon
          icon="i-lucide-loader-2"
          class="size-8 text-n-blue-11 animate-spin"
        />
        <span class="text-sm text-n-slate-11">
          {{ t('SIDEBAR.SATURN_PRODUCTS_LOADING') }}
        </span>
      </div>
    </div>

    <!-- Shopify Not Connected State -->
    <div
      v-else-if="!isShopifyConnected"
      class="flex flex-col items-center justify-center py-20 text-center"
    >
      <Icon icon="i-logos-shopify" class="size-16 mb-4" />
      <h3 class="text-lg font-medium text-n-slate-12 mb-2">
        {{ t('SIDEBAR.SATURN_PRODUCTS_SHOPIFY_REQUIRED') }}
      </h3>
      <p class="text-sm text-n-slate-11 max-w-md mb-6">
        {{ t('SIDEBAR.SATURN_PRODUCTS_SHOPIFY_REQUIRED_DESC') }}
      </p>
      <Button variant="solid" color-scheme="primary" @click="goToIntegrations">
        {{ t('SIDEBAR.SATURN_PRODUCTS_GO_TO_INTEGRATIONS') }}
      </Button>
    </div>

    <!-- Empty State -->
    <div
      v-else-if="isEmpty"
      class="flex flex-col items-center justify-center py-20 text-center"
    >
      <Icon icon="i-lucide-package" class="size-16 text-n-slate-9 mb-4" />
      <h3 class="text-lg font-medium text-n-slate-12 mb-2">
        {{
          searchQuery
            ? t('SIDEBAR.SATURN_PRODUCTS_NOT_FOUND')
            : t('SIDEBAR.SATURN_PRODUCTS_EMPTY')
        }}
      </h3>
      <p class="text-sm text-n-slate-11 max-w-md">
        {{
          searchQuery
            ? t('SIDEBAR.SATURN_PRODUCTS_TRY_DIFFERENT')
            : t('SIDEBAR.SATURN_PRODUCTS_SYNC_INFO')
        }}
      </p>
    </div>

    <!-- Products Grid -->
    <div
      v-else
      class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4"
    >
      <div
        v-for="product in products"
        :key="product.id"
        class="bg-n-solid-3 rounded-lg border border-n-weak overflow-hidden hover:border-n-slate-7 transition-colors"
      >
        <!-- Product Image -->
        <div class="aspect-square bg-n-solid-2 relative">
          <img
            v-if="getProductImage(product)"
            :src="getProductImage(product)"
            :alt="product.title"
            class="w-full h-full object-cover"
          />
          <div v-else class="w-full h-full flex items-center justify-center">
            <Icon icon="i-lucide-image-off" class="size-12 text-n-slate-8" />
          </div>
        </div>

        <!-- Product Info -->
        <div class="p-4">
          <h3
            class="font-medium text-n-slate-12 text-sm line-clamp-2 mb-1"
            :title="product.title"
          >
            {{ product.title }}
          </h3>

          <p v-if="product.vendor" class="text-xs text-n-slate-11 mb-2">
            {{ product.vendor }}
          </p>

          <div class="flex items-center justify-between mt-3">
            <span class="font-semibold text-n-slate-12">
              {{ formatPrice(product.min_price, product.max_price) }}
            </span>
            <span
              class="text-xs font-medium"
              :class="getInventoryClass(product.total_inventory)"
            >
              {{ formatInventory(product.total_inventory) }}
            </span>
          </div>

          <div v-if="product.product_type" class="mt-2">
            <span
              class="inline-block px-2 py-0.5 text-xs rounded-full bg-n-alpha-2 text-n-slate-11"
            >
              {{ product.product_type }}
            </span>
          </div>
        </div>
      </div>
    </div>
  </SaturnPageLayout>
</template>

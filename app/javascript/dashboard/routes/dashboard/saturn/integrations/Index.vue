<script setup>
import { computed, onMounted, onUnmounted, ref } from 'vue';
import { useAlert } from 'dashboard/composables';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import SaturnPageLayout from 'dashboard/components-next/saturn/SaturnPageLayout.vue';
import shopifyAPI from 'dashboard/api/integrations/shopify';
import Input from 'dashboard/components-next/input/Input.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { useI18n } from 'vue-i18n';

const { t } = useI18n();
const integrations = ref([]);
const isFetching = ref(false);
const shopifyHook = ref(null);

// Connection test status for each integration
const connectionTestStatus = ref({});
const isTestingConnection = ref({});

// All available integrations
const allIntegrations = ref([
  {
    id: 'shopify',
    name: 'Shopify',
    description:
      'Shopify mağazanıza bağlanın ve sipariş bilgilerini sorgulayın',
    icon: 'i-logos-shopify',
    connected: false,
    hook: null,
    comingSoon: false,
    totalSyncedProducts: 0,
  },
  {
    id: 'ikas',
    name: 'İkas',
    description: 'İkas mağazanıza bağlanın ve sipariş bilgilerini sorgulayın',
    icon: 'i-lucide-store',
    connected: false,
    hook: null,
    comingSoon: true,
  },
]);

// Shopify connection dialog
const shopifyDialogRef = ref(null);
const shopifyStoreUrl = ref('');
const shopifyAccessKey = ref('');
const isConnectingShopify = ref(false);
const shopifyError = ref('');

// Test order query
const testOrderDialogRef = ref(null);
const testContactId = ref('');
const testOrders = ref([]);
const isFetchingOrders = ref(false);

// Product sync
const syncStatus = ref(null);
const isSyncing = ref(false);
const syncInterval = ref(null);
const totalSyncedProducts = ref(0);

// Image Search Feature
const imageSearchEnabled = ref(false);
const imageSearchDialogRef = ref(null);

const isEmpty = computed(() => {
  return allIntegrations.value.length === 0;
});

const fetchIntegrations = async () => {
  isFetching.value = true;
  try {
    const response = await shopifyAPI.getHook();

    // Handle both direct response and nested data
    const hookData = response.data?.hook || response.hook;

    if (hookData && (hookData.id || hookData.reference_id)) {
      shopifyHook.value = {
        id: hookData.id,
        reference_id: hookData.reference_id,
        enabled: hookData.enabled !== false,
        settings: hookData.settings || {},
      };
      // Image search durumunu güncelle
      imageSearchEnabled.value = hookData.settings?.image_search_enabled || false;

      // Update allIntegrations
      const shopifyIntegration = allIntegrations.value.find(
        i => i.id === 'shopify'
      );
      if (shopifyIntegration) {
        shopifyIntegration.connected = true;
        shopifyIntegration.hook = shopifyHook.value;
      }

      integrations.value = [
        {
          id: 'shopify',
          enabled: shopifyHook.value.enabled,
          reference_id: shopifyHook.value.reference_id,
        },
      ];
    } else {
      shopifyHook.value = null;
      integrations.value = [];

      // Update allIntegrations
      const shopifyIntegration = allIntegrations.value.find(
        i => i.id === 'shopify'
      );
      if (shopifyIntegration) {
        shopifyIntegration.connected = false;
        shopifyIntegration.hook = null;
      }
    }
  } catch (error) {
    if (error.response?.status === 404) {
      // Hook bulunamadı, entegrasyon yok
      shopifyHook.value = null;
      integrations.value = [];
    } else {
      shopifyHook.value = null;
      integrations.value = [];
    }

    // Update allIntegrations
    const shopifyIntegration = allIntegrations.value.find(
      i => i.id === 'shopify'
    );
    if (shopifyIntegration) {
      shopifyIntegration.connected = false;
      shopifyIntegration.hook = null;
    }
  } finally {
    isFetching.value = false;
  }
};

const openShopifyDialog = () => {
  shopifyStoreUrl.value = shopifyHook.value?.reference_id || '';
  shopifyAccessKey.value = '';
  shopifyError.value = '';
  if (shopifyDialogRef.value) {
    shopifyDialogRef.value.open();
  }
};

const handleShopifyDisconnect = async () => {
  try {
    await shopifyAPI.disconnect();
    await fetchIntegrations();
    useAlert(t('SIDEBAR.INTEGRATIONS.SHOPIFY.DISCONNECT_SUCCESS'), 'success');
  } catch (error) {
    useAlert(t('SIDEBAR.INTEGRATIONS.SHOPIFY.DISCONNECT_ERROR'), 'error');
  }
};

const handleIntegrationClick = integration => {
  // Coming soon entegrasyonlar için tıklamayı devre dışı bırak
  if (integration.comingSoon) {
    return;
  }

  // Bağlı entegrasyonlar için tıklamayı devre dışı bırak
  if (integration.connected) {
    return;
  }

  // Bağlı olmayan entegrasyon için bağlantı dialogunu aç
  if (integration.id === 'shopify') {
    openShopifyDialog();
  }
};

const handleEditIntegration = integration => {
  if (integration.id === 'shopify') {
    openShopifyDialog();
  }
};

const handleDisconnectIntegration = async integration => {
  const confirmed = window.confirm(
    t('SIDEBAR.INTEGRATIONS.DISCONNECT_CONFIRM')
  );
  if (!confirmed) return;

  if (integration.id === 'shopify') {
    await handleShopifyDisconnect();
  }
};

const testConnection = async integration => {
  if (!integration.connected) return;

  isTestingConnection.value[integration.id] = true;
  connectionTestStatus.value[integration.id] = null;

  try {
    if (integration.id === 'shopify') {
      await shopifyAPI.testConnection();
      connectionTestStatus.value[integration.id] = 'success';
      useAlert(t('SIDEBAR.INTEGRATIONS.SHOPIFY.TEST_SUCCESS'), 'success');
    }
  } catch (error) {
    connectionTestStatus.value[integration.id] = 'error';
    useAlert(
      `${t('SIDEBAR.INTEGRATIONS.SHOPIFY.TEST_ERROR')}: ${
        error.response?.data?.error || error.message
      }`,
      'error'
    );
  } finally {
    isTestingConnection.value[integration.id] = false;
    // 3 saniye sonra durumu temizle
    setTimeout(() => {
      connectionTestStatus.value[integration.id] = null;
    }, 3000);
  }
};

const validateStoreUrl = url => {
  const pattern = /^[a-zA-Z0-9][a-zA-Z0-9-]*\.myshopify\.com$/;
  return pattern.test(url);
};

const startSyncStatusPolling = () => {
  // Mevcut interval'i temizle
  if (syncInterval.value) {
    clearInterval(syncInterval.value);
  }

  // Her 3 saniyede bir sync durumunu kontrol et
  syncInterval.value = setInterval(async () => {
    if (!shopifyHook.value?.id) {
      clearInterval(syncInterval.value);
      return;
    }

    try {
      const { data } = await shopifyAPI.getSyncStatus();
      syncStatus.value = data.sync_status;

      // Sync tamamlandı veya başarısız olduysa polling'i durdur
      if (
        syncStatus.value &&
        (syncStatus.value.status === 'completed' ||
          syncStatus.value.status === 'failed')
      ) {
        clearInterval(syncInterval.value);
        syncInterval.value = null;

        if (syncStatus.value.status === 'completed') {
          useAlert(
            t('SIDEBAR.INTEGRATIONS.SHOPIFY.SYNC_COMPLETED', {
              count: syncStatus.value.synced_products,
            }),
            'success'
          );
        } else if (syncStatus.value.status === 'failed') {
          const errorMsg = syncStatus.value.error_message
            ? `: ${syncStatus.value.error_message}`
            : '';
          useAlert(
            t('SIDEBAR.INTEGRATIONS.SHOPIFY.SYNC_FAILED') + errorMsg,
            'error'
          );
        }
      }
    } catch (error) {
      // eslint-disable-next-line no-console
      // Hata durumunda polling'i durdurma
    }
  }, 3000);
};

const fetchSyncStatus = async () => {
  if (!shopifyHook.value?.id) {
    syncStatus.value = null;
    totalSyncedProducts.value = 0;
    return;
  }

  try {
    const { data } = await shopifyAPI.getSyncStatus();
    syncStatus.value = data.sync_status;
    totalSyncedProducts.value = data.total_synced_products || 0;

    // Update integration object with product count
    const shopifyIntegration = allIntegrations.value.find(
      i => i.id === 'shopify'
    );
    if (shopifyIntegration) {
      shopifyIntegration.totalSyncedProducts = data.total_synced_products || 0;
    }

    // Debug logging
    // eslint-disable-next-line no-console
    console.log('[Shopify] Sync status fetched:', {
      syncStatus: data.sync_status,
      totalProducts: data.total_synced_products,
      integrationUpdated: !!shopifyIntegration,
    });

    // Eğer aktif bir sync varsa polling başlat
    if (
      syncStatus.value &&
      (syncStatus.value.status === 'pending' ||
        syncStatus.value.status === 'syncing')
    ) {
      startSyncStatusPolling();
    }
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error('[Shopify] Error fetching sync status:', error);
    syncStatus.value = null;
    totalSyncedProducts.value = 0;
  }
};

const handleShopifyConnect = async () => {
  try {
    shopifyError.value = '';
    if (!validateStoreUrl(shopifyStoreUrl.value)) {
      shopifyError.value = t('SIDEBAR.INTEGRATIONS.SHOPIFY.STORE_URL_MESSAGE');
      return;
    }
    if (!shopifyAccessKey.value || shopifyAccessKey.value.trim().length === 0) {
      shopifyError.value = t('SIDEBAR.INTEGRATIONS.SHOPIFY.ACCESS_KEY_MESSAGE');
      return;
    }

    isConnectingShopify.value = true;
    const { data } = await shopifyAPI.connectWithAccessKey({
      shopDomain: shopifyStoreUrl.value,
      accessKey: shopifyAccessKey.value,
    });

    // Update hook data from response
    const hookData = data?.hook || data;

    if (hookData && (hookData.id || hookData.reference_id)) {
      shopifyHook.value = {
        id: hookData.id,
        reference_id: hookData.reference_id,
        enabled: hookData.enabled !== false,
      };
      integrations.value = [
        {
          id: 'shopify',
          enabled: shopifyHook.value.enabled,
          reference_id: shopifyHook.value.reference_id,
        },
      ];
    } else {
      // Fallback to fetch if response format is different
      await fetchIntegrations();
    }

    useAlert(t('SIDEBAR.INTEGRATIONS.SHOPIFY.CONNECT_SUCCESS'), 'success');
    if (shopifyDialogRef.value) {
      shopifyDialogRef.value.close();
    }
    // Hook bağlandıktan sonra sync durumunu kontrol et
    setTimeout(() => {
      fetchSyncStatus();
    }, 500);
  } catch (error) {
    shopifyError.value =
      error.response?.data?.error ||
      error.message ||
      t('SIDEBAR.INTEGRATIONS.SHOPIFY.CONNECTION_ERROR');
  } finally {
    isConnectingShopify.value = false;
  }
};

const handleTestOrderQuery = async () => {
  if (!testContactId.value) {
    useAlert(t('SIDEBAR.INTEGRATIONS.TEST_ORDER.CONTACT_ID_REQUIRED'), 'error');
    return;
  }

  isFetchingOrders.value = true;
  try {
    const { data } = await shopifyAPI.getOrders(testContactId.value);
    testOrders.value = data.orders || [];
    if (testOrders.value.length === 0) {
      useAlert(t('SIDEBAR.INTEGRATIONS.TEST_ORDER.NO_ORDERS'), 'info');
    }
  } catch (error) {
    useAlert(
      error.response?.data?.error ||
        t('SIDEBAR.INTEGRATIONS.TEST_ORDER.QUERY_ERROR'),
      'error'
    );
    testOrders.value = [];
  } finally {
    isFetchingOrders.value = false;
  }
};

const handleShopifySync = async (incremental = false) => {
  if (!shopifyHook.value?.id) return;

  isSyncing.value = true;

  // Optimistic update
  syncStatus.value = {
    status: 'in_progress',
    synced_products: 0,
    total_products: totalSyncedProducts.value || 0,
    progress_percentage: 0,
  };

  try {
    const { data } = await shopifyAPI.syncProducts(incremental);
    useAlert(
      data.message || t('SIDEBAR.INTEGRATIONS.SHOPIFY.SYNC_STARTED'),
      'success'
    );
    // Immediately fetch actual sync status
    await fetchSyncStatus();
    // Sync durumunu kontrol etmeye başla
    startSyncStatusPolling();
  } catch (error) {
    // Clear optimistic update on error
    await fetchSyncStatus();
    useAlert(
      error.response?.data?.error ||
        t('SIDEBAR.INTEGRATIONS.SHOPIFY.SYNC_ERROR'),
      'error'
    );
  } finally {
    isSyncing.value = false;
  }
};

// Incremental sync - sadece güncellenmiş/yeni ürünleri çeker
const handleResync = async () => {
  const confirmed = window.confirm(
    t('SIDEBAR.INTEGRATIONS.SHOPIFY.RESYNC_CONFIRM')
  );

  if (!confirmed) return;

  // Eğer daha önce sync yapılmışsa incremental, yoksa full sync
  const hasCompletedSync =
    syncStatus.value?.status === 'completed' || totalSyncedProducts.value > 0;
  await handleShopifySync(hasCompletedSync);
};

const formatDate = dateString => {
  if (!dateString) return '';
  const date = new Date(dateString);
  return new Intl.DateTimeFormat('tr-TR', {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(date);
};

// Image Search Toggle Handler
const handleImageSearchToggle = async () => {
  const newValue = !imageSearchEnabled.value;
  
  try {
    await shopifyAPI.updateSettings({ image_search_enabled: newValue });
    imageSearchEnabled.value = newValue;
    
    // Hook'u da güncelle
    if (shopifyHook.value) {
      shopifyHook.value.settings = {
        ...shopifyHook.value.settings,
        image_search_enabled: newValue,
      };
    }
    
    useAlert(
      newValue
        ? t('SIDEBAR.INTEGRATIONS.SHOPIFY.IMAGE_SEARCH.ENABLED_SUCCESS')
        : t('SIDEBAR.INTEGRATIONS.SHOPIFY.IMAGE_SEARCH.DISABLED_SUCCESS')
    );
  } catch (error) {
    useAlert(t('SIDEBAR.INTEGRATIONS.SHOPIFY.IMAGE_SEARCH.UPDATE_ERROR'));
  }
};

onMounted(async () => {
  await fetchIntegrations();
  await fetchSyncStatus();
});

// Component unmount olduğunda interval'i temizle
onUnmounted(() => {
  if (syncInterval.value) {
    clearInterval(syncInterval.value);
  }
});
</script>

<template>
  <SaturnPageLayout
    :page-title="$t('SIDEBAR.SATURN_INTEGRATIONS')"
    :action-button-text="null"
    :action-permissions="['administrator']"
    :enable-pagination="false"
    :is-loading="isFetching"
    :has-no-data="isEmpty"
    :total-records="allIntegrations.length"
    :feature-flag-key="FEATURE_FLAGS.SATURN"
  >
    <template #emptyStateSection>
      <div class="text-center py-12">
        <p class="text-lg text-n-slate-11">
          {{ $t('SIDEBAR.INTEGRATIONS.EMPTY_STATE_TITLE') }}
        </p>
        <p class="text-sm text-n-slate-10 mt-2">
          {{ $t('SIDEBAR.INTEGRATIONS.EMPTY_STATE_DESCRIPTION') }}
        </p>
      </div>
    </template>

    <template #contentArea>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        <div
          v-for="integration in allIntegrations"
          :key="integration.id"
          class="bg-n-slate-1 border border-n-slate-4 rounded-lg p-6 transition-colors relative"
          :class="{
            'cursor-pointer hover:border-n-slate-6':
              !integration.comingSoon && !integration.connected,
            'opacity-50 cursor-not-allowed': integration.comingSoon,
          }"
          @click="handleIntegrationClick(integration)"
        >
          <div
            v-if="integration.comingSoon"
            class="absolute top-3 right-3 bg-n-amber-9/20 text-n-amber-11 text-xs font-medium px-2 py-1 rounded"
          >
            {{ $t('SIDEBAR.INTEGRATIONS.COMING_SOON') }}
          </div>
          <div class="flex items-start justify-between mb-4">
            <div class="flex items-center gap-3 flex-1">
              <div
                class="w-12 h-12 bg-n-slate-2 rounded-lg flex items-center justify-center flex-shrink-0"
              >
                <Icon :icon="integration.icon" class="w-8 h-8" />
              </div>
              <div class="flex-1 min-w-0">
                <h3 class="text-base font-semibold text-n-slate-12 truncate">
                  {{ integration.name }}
                </h3>
                <p class="text-sm text-n-slate-11 mt-1 line-clamp-2">
                  {{ integration.description }}
                </p>
              </div>
            </div>
            <div
              v-if="integration.connected && !integration.comingSoon"
              class="flex-shrink-0 ml-2 flex items-center gap-2"
            >
              <!-- Connection Test Button -->
              <button
                type="button"
                class="flex items-center justify-center w-8 h-8 rounded-lg transition-colors"
                :class="{
                  'bg-n-teal-9/20 text-n-teal-11':
                    connectionTestStatus[integration.id] === 'success',
                  'bg-n-ruby-9/20 text-n-ruby-11':
                    connectionTestStatus[integration.id] === 'error',
                  'bg-n-slate-2 text-n-slate-11 hover:bg-n-slate-3':
                    !connectionTestStatus[integration.id],
                }"
                :disabled="isTestingConnection[integration.id]"
                :title="$t('SIDEBAR.INTEGRATIONS.TEST_CONNECTION')"
                @click.stop="testConnection(integration)"
              >
                <Icon
                  v-if="isTestingConnection[integration.id]"
                  icon="i-lucide-loader-2"
                  class="w-4 h-4 animate-spin"
                />
                <Icon
                  v-else-if="connectionTestStatus[integration.id] === 'success'"
                  icon="i-lucide-check"
                  class="w-4 h-4"
                />
                <Icon
                  v-else-if="connectionTestStatus[integration.id] === 'error'"
                  icon="i-lucide-x"
                  class="w-4 h-4"
                />
                <Icon v-else icon="i-lucide-link" class="w-4 h-4" />
              </button>
              <!-- Edit Button -->
              <button
                type="button"
                class="flex items-center justify-center w-8 h-8 rounded-lg bg-n-slate-2 text-n-slate-11 hover:bg-n-slate-3 transition-colors"
                :title="$t('SIDEBAR.INTEGRATIONS.EDIT')"
                @click.stop="handleEditIntegration(integration)"
              >
                <Icon icon="i-lucide-pencil" class="w-4 h-4" />
              </button>
              <!-- Disconnect Button -->
              <button
                type="button"
                class="flex items-center justify-center w-8 h-8 rounded-lg bg-n-ruby-3 text-n-ruby-11 hover:bg-n-ruby-4 transition-colors"
                :title="$t('SIDEBAR.INTEGRATIONS.DISCONNECT')"
                @click.stop="handleDisconnectIntegration(integration)"
              >
                <Icon icon="i-lucide-unplug" class="w-4 h-4" />
              </button>
            </div>
            <div v-else-if="!integration.comingSoon" class="flex-shrink-0 ml-2">
              <Icon
                icon="i-lucide-chevron-right"
                class="w-5 h-5 text-n-slate-9"
              />
            </div>
          </div>
          <div
            v-if="integration.connected && integration.hook?.reference_id"
            class="pt-4 border-t border-n-slate-4 space-y-3"
          >
            <div class="flex items-center justify-between">
              <p class="text-xs text-n-slate-11">
                <span class="font-medium">
                  {{ $t('SIDEBAR.INTEGRATIONS.STORE') }}
                </span>
                {{ integration.hook.reference_id }}
              </p>
              <p
                v-if="integration.id === 'shopify' && totalSyncedProducts > 0"
                class="text-xs font-medium text-n-blue-11"
              >
                {{ totalSyncedProducts }}
                {{ $t('SIDEBAR.INTEGRATIONS.SHOPIFY.PRODUCTS') }}
              </p>
            </div>

            <!-- Sync Section (only for Shopify) -->
            <div v-if="integration.id === 'shopify'" class="space-y-3">
              <!-- Sync button -->
              <button
                v-if="syncStatus?.status !== 'in_progress'"
                class="w-full flex items-center justify-center gap-2 px-4 py-2 text-sm font-medium text-n-blue-11 bg-n-blue-3 hover:bg-n-blue-4 rounded-lg transition-colors"
                :disabled="syncStatus?.status === 'in_progress'"
                @click="handleResync"
              >
                <Icon
                  :icon="
                    syncStatus?.status === 'in_progress'
                      ? 'i-lucide-loader-2'
                      : 'i-lucide-refresh-cw'
                  "
                  :class="{
                    'animate-spin': syncStatus?.status === 'in_progress',
                  }"
                  class="w-4 h-4"
                />
                {{ $t('SIDEBAR.INTEGRATIONS.SHOPIFY.RESYNC_PRODUCTS') }}
              </button>

              <!-- Status Display -->
              <div class="flex items-center gap-1 text-xs">
                <span class="text-n-slate-11">{{
                  $t('SIDEBAR.INTEGRATIONS.SHOPIFY.STATUS_LABEL')
                }}</span>
                <span
                  class="font-medium"
                  :class="{
                    'text-n-amber-11': syncStatus?.status === 'pending',
                    'text-n-blue-11': syncStatus?.status === 'syncing',
                    'text-n-teal-11':
                      syncStatus?.status === 'completed' || !syncStatus,
                    'text-n-ruby-11': syncStatus?.status === 'failed',
                  }"
                >
                  {{
                    syncStatus?.status === 'pending'
                      ? $t('SIDEBAR.INTEGRATIONS.SHOPIFY.STATUS_PENDING')
                      : syncStatus?.status === 'syncing'
                        ? $t('SIDEBAR.INTEGRATIONS.SHOPIFY.STATUS_SYNCING')
                        : syncStatus?.status === 'failed'
                          ? $t('SIDEBAR.INTEGRATIONS.SHOPIFY.STATUS_FAILED')
                          : $t('SIDEBAR.INTEGRATIONS.SHOPIFY.STATUS_COMPLETED')
                  }}
                </span>
              </div>

              <!-- Last sync time -->
              <p
                v-if="syncStatus?.completed_at"
                class="text-xs text-n-slate-10 text-center"
              >
                {{ $t('SIDEBAR.INTEGRATIONS.SHOPIFY.LAST_SYNC') }}:
                {{ formatDate(syncStatus.completed_at) }}
              </p>

              <!-- Progress Bar (when syncing) -->
              <div
                v-if="
                  syncStatus &&
                  (syncStatus.status === 'syncing' ||
                    syncStatus.status === 'pending')
                "
                class="space-y-1"
              >
                <div
                  class="w-full bg-n-slate-3 rounded-full h-2 overflow-hidden"
                >
                  <div
                    class="h-full bg-n-blue-9 transition-all duration-300"
                    :style="{
                      width: `${syncStatus.progress_percentage || 0}%`,
                    }"
                  />
                </div>
                <div
                  v-if="syncStatus.total_products > 0"
                  class="text-xs text-n-slate-11 text-center"
                >
                  {{
                    $t('SIDEBAR.INTEGRATIONS.SHOPIFY.SYNC_PROGRESS', {
                      synced: syncStatus.synced_products || 0,
                      total: syncStatus.total_products,
                      percentage: Math.round(
                        syncStatus.progress_percentage || 0
                      ),
                    })
                  }}
                </div>
              </div>

              <!-- Error Message -->
              <div
                v-if="
                  syncStatus?.status === 'failed' && syncStatus?.error_message
                "
                class="text-xs text-n-ruby-11 bg-n-ruby-9/20 p-2 rounded"
              >
                {{ syncStatus.error_message }}
              </div>

              <!-- Image Search Feature Toggle -->
              <div class="pt-3 border-t border-n-slate-4">
                <div class="flex items-center justify-between">
                  <div class="flex items-center gap-2">
                    <Icon icon="i-lucide-image-search" class="w-4 h-4 text-n-slate-11" />
                    <span class="text-sm font-medium text-n-slate-12">
                      {{ $t('SIDEBAR.INTEGRATIONS.SHOPIFY.IMAGE_SEARCH.TITLE') }}
                    </span>
                  </div>
                  <button
                    type="button"
                    class="relative inline-flex h-6 w-11 items-center rounded-full transition-colors"
                    :class="imageSearchEnabled ? 'bg-n-teal-9' : 'bg-n-slate-4'"
                    @click.stop="handleImageSearchToggle"
                  >
                    <span
                      class="inline-block h-4 w-4 transform rounded-full bg-white transition-transform"
                      :class="imageSearchEnabled ? 'translate-x-6' : 'translate-x-1'"
                    />
                  </button>
                </div>
                <p class="text-xs text-n-slate-10 mt-1">
                  {{ $t('SIDEBAR.INTEGRATIONS.SHOPIFY.IMAGE_SEARCH.DESCRIPTION') }}
                </p>
                <div
                  v-if="imageSearchEnabled"
                  class="mt-2 flex items-center gap-1 text-xs text-n-teal-11"
                >
                  <Icon icon="i-lucide-check-circle" class="w-3 h-3" />
                  <span>{{ $t('SIDEBAR.INTEGRATIONS.SHOPIFY.IMAGE_SEARCH.ACTIVE') }}</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </template>

    <!-- Shopify Connect Dialog -->
    <Dialog
      ref="shopifyDialogRef"
      :title="
        shopifyHook
          ? $t('SIDEBAR.INTEGRATIONS.SHOPIFY.EDIT_TITLE')
          : $t('SIDEBAR.INTEGRATIONS.SHOPIFY.CONNECT_TITLE')
      "
      :is-loading="isConnectingShopify"
      @confirm="handleShopifyConnect"
      @close="
        () => {
          shopifyStoreUrl = '';
          shopifyAccessKey = '';
          shopifyError = '';
        }
      "
    >
      <div class="space-y-4">
        <Input
          v-model="shopifyStoreUrl"
          :label="$t('SIDEBAR.INTEGRATIONS.SHOPIFY.STORE_URL_LABEL')"
          :placeholder="
            $t('SIDEBAR.INTEGRATIONS.SHOPIFY.STORE_URL_PLACEHOLDER')
          "
          :message="
            shopifyError && shopifyError.includes('URL')
              ? shopifyError
              : $t('SIDEBAR.INTEGRATIONS.SHOPIFY.STORE_URL_MESSAGE')
          "
          :message-type="
            shopifyError && shopifyError.includes('URL') ? 'error' : 'info'
          "
        />
        <Input
          v-model="shopifyAccessKey"
          :label="$t('SIDEBAR.INTEGRATIONS.SHOPIFY.ACCESS_KEY_LABEL')"
          type="password"
          :placeholder="
            $t('SIDEBAR.INTEGRATIONS.SHOPIFY.ACCESS_KEY_PLACEHOLDER')
          "
          :message="
            shopifyError && shopifyError.includes('Access')
              ? shopifyError
              : $t('SIDEBAR.INTEGRATIONS.SHOPIFY.ACCESS_KEY_MESSAGE')
          "
          :message-type="
            shopifyError && shopifyError.includes('Access') ? 'error' : 'info'
          "
        />
      </div>
    </Dialog>

    <!-- Image Search Info Dialog -->
    <Dialog
      ref="imageSearchDialogRef"
      :title="$t('SIDEBAR.INTEGRATIONS.SHOPIFY.IMAGE_SEARCH.DIALOG_TITLE')"
      :confirm-text="$t('SIDEBAR.INTEGRATIONS.SHOPIFY.IMAGE_SEARCH.DIALOG_CONFIRM')"
      @confirm="() => imageSearchDialogRef?.close()"
    >
      <div class="space-y-4">
        <div class="flex items-center justify-center">
          <div class="w-16 h-16 bg-n-amber-3 rounded-full flex items-center justify-center">
            <Icon icon="i-lucide-image-search" class="w-8 h-8 text-n-amber-11" />
          </div>
        </div>
        <p class="text-center text-n-slate-12">
          {{ $t('SIDEBAR.INTEGRATIONS.SHOPIFY.IMAGE_SEARCH.DIALOG_MESSAGE') }}
        </p>
        <div class="bg-n-slate-2 p-4 rounded-lg">
          <h4 class="font-medium text-n-slate-12 mb-2">
            {{ $t('SIDEBAR.INTEGRATIONS.SHOPIFY.IMAGE_SEARCH.FEATURES_TITLE') }}
          </h4>
          <ul class="space-y-2 text-sm text-n-slate-11">
            <li class="flex items-start gap-2">
              <Icon icon="i-lucide-check" class="w-4 h-4 text-n-teal-11 mt-0.5" />
              <span>{{ $t('SIDEBAR.INTEGRATIONS.SHOPIFY.IMAGE_SEARCH.FEATURE_1') }}</span>
            </li>
            <li class="flex items-start gap-2">
              <Icon icon="i-lucide-check" class="w-4 h-4 text-n-teal-11 mt-0.5" />
              <span>{{ $t('SIDEBAR.INTEGRATIONS.SHOPIFY.IMAGE_SEARCH.FEATURE_2') }}</span>
            </li>
            <li class="flex items-start gap-2">
              <Icon icon="i-lucide-check" class="w-4 h-4 text-n-teal-11 mt-0.5" />
              <span>{{ $t('SIDEBAR.INTEGRATIONS.SHOPIFY.IMAGE_SEARCH.FEATURE_3') }}</span>
            </li>
          </ul>
        </div>
        <p class="text-xs text-n-slate-10 text-center">
          {{ $t('SIDEBAR.INTEGRATIONS.SHOPIFY.IMAGE_SEARCH.CONTACT_INFO') }}
        </p>
      </div>
    </Dialog>

    <!-- Test Order Query Dialog -->
    <Dialog
      ref="testOrderDialogRef"
      :title="$t('SIDEBAR.INTEGRATIONS.TEST_ORDER.TITLE')"
      :is-loading="isFetchingOrders"
      @confirm="handleTestOrderQuery"
      @close="
        () => {
          testContactId = '';
          testOrders = [];
        }
      "
    >
      <Input
        v-model="testContactId"
        :label="$t('SIDEBAR.INTEGRATIONS.TEST_ORDER.CONTACT_ID_LABEL')"
        :placeholder="
          $t('SIDEBAR.INTEGRATIONS.TEST_ORDER.CONTACT_ID_PLACEHOLDER')
        "
        :message="$t('SIDEBAR.INTEGRATIONS.TEST_ORDER.CONTACT_ID_MESSAGE')"
        message-type="info"
      />
      <div v-if="testOrders.length > 0" class="mt-4">
        <h4 class="font-semibold mb-2 text-n-slate-12">
          {{
            $t('SIDEBAR.INTEGRATIONS.TEST_ORDER.ORDERS_TITLE_WITH_COUNT', {
              count: testOrders.length,
            })
          }}
        </h4>
        <div class="space-y-2 max-h-64 overflow-y-auto">
          <div
            v-for="order in testOrders"
            :key="order.id"
            class="p-3 bg-n-slate-2 border border-n-slate-4 rounded"
          >
            <div class="flex justify-between items-start">
              <div>
                <p class="font-medium text-n-slate-12">
                  {{ $t('SIDEBAR.INTEGRATIONS.TEST_ORDER.ORDER_NUMBER')
                  }}{{ order.id }}
                </p>
                <p class="text-sm text-n-slate-11">
                  {{ new Date(order.created_at).toLocaleDateString('tr-TR') }}
                </p>
                <p class="text-sm text-n-slate-11">
                  <span class="font-medium">{{
                    $t('SIDEBAR.INTEGRATIONS.TEST_ORDER.STATUS')
                  }}</span>
                  {{
                    order.fulfillment_status ||
                    $t('SIDEBAR.INTEGRATIONS.TEST_ORDER.PENDING')
                  }}
                </p>
              </div>
              <div class="text-right">
                <p class="font-semibold text-n-slate-12">
                  {{ order.total_price }} {{ order.currency }}
                </p>
                <a
                  :href="order.admin_url"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="text-xs text-n-blue-11 hover:text-n-blue-12 hover:underline"
                >
                  {{ $t('SIDEBAR.INTEGRATIONS.TEST_ORDER.VIEW_IN_SHOPIFY') }}
                </a>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Dialog>
  </SaturnPageLayout>
</template>

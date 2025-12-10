<script setup>
import { computed, onMounted, onUnmounted, ref } from 'vue';
import { useAlert } from 'dashboard/composables';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import SaturnPageLayout from 'dashboard/components-next/saturn/SaturnPageLayout.vue';
import shopifyAPI from 'dashboard/api/integrations/shopify';
import Input from 'dashboard/components-next/input/Input.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
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

// Shopify disconnect dialog
const disconnectDialogRef = ref(null);
const isDisconnecting = ref(false);
const disconnectIntegration = ref(null);

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

// Feature Toggles
const orderQueryEnabled = ref(true);
const productQueryEnabled = ref(true);
const imageSearchEnabled = ref(false);
const imageSearchDialogRef = ref(null);
const isUpdatingSettings = ref(false);

const isEmpty = computed(() => {
  return allIntegrations.value.length === 0;
});

// Sync işlemi devam ediyor mu?
const isSyncInProgress = computed(() => {
  return syncStatus.value?.status === 'pending' || 
         syncStatus.value?.status === 'syncing' ||
         isSyncing.value;
});

// Dinamik durum metni
const syncStatusText = computed(() => {
  if (!syncStatus.value) {
    return totalSyncedProducts.value > 0 
      ? t('SIDEBAR.INTEGRATIONS.SHOPIFY.STATUS_READY', { count: totalSyncedProducts.value })
      : t('SIDEBAR.INTEGRATIONS.SHOPIFY.STATUS_NO_PRODUCTS');
  }
  
  switch (syncStatus.value.status) {
    case 'pending':
      return t('SIDEBAR.INTEGRATIONS.SHOPIFY.STATUS_STARTING');
    case 'syncing':
      if (syncStatus.value.total_products > 0) {
        return t('SIDEBAR.INTEGRATIONS.SHOPIFY.SYNC_PROGRESS', {
          synced: syncStatus.value.synced_products || 0,
          total: syncStatus.value.total_products,
          percentage: Math.round(syncStatus.value.progress_percentage || 0)
        });
      }
      return t('SIDEBAR.INTEGRATIONS.SHOPIFY.STATUS_SYNCING');
    case 'completed':
      return t('SIDEBAR.INTEGRATIONS.SHOPIFY.STATUS_COMPLETED');
    case 'failed':
      return t('SIDEBAR.INTEGRATIONS.SHOPIFY.STATUS_FAILED');
    default:
      return t('SIDEBAR.INTEGRATIONS.SHOPIFY.STATUS_COMPLETED');
  }
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
      // Feature toggle durumlarını güncelle
      orderQueryEnabled.value = hookData.settings?.order_query_enabled !== false; // varsayılan true
      productQueryEnabled.value = hookData.settings?.product_query_enabled !== false; // varsayılan true
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
    const response = await shopifyAPI.disconnect();
    await fetchIntegrations();
    
    // Silinen ürün sayısını göster
    const message = response.data?.message || t('SIDEBAR.INTEGRATIONS.SHOPIFY.DISCONNECT_SUCCESS');
    useAlert(message, 'success');
    
    // Sync durumunu sıfırla
    syncStatus.value = null;
    totalSyncedProducts.value = 0;
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

const handleDisconnectIntegration = integration => {
  // Dialog'u aç
  disconnectIntegration.value = integration;
  if (disconnectDialogRef.value) {
    disconnectDialogRef.value.open();
  }
};

const handleConfirmDisconnect = async () => {
  if (!disconnectIntegration.value) return;
  
  isDisconnecting.value = true;
  
  try {
    if (disconnectIntegration.value.id === 'shopify') {
      await handleShopifyDisconnect();
    }
    
    // Dialog'u kapat
    if (disconnectDialogRef.value) {
      disconnectDialogRef.value.close();
    }
  } finally {
    isDisconnecting.value = false;
    disconnectIntegration.value = null;
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

const validateStoreName = name => {
  // Sadece store adını doğrula (myshopify.com olmadan)
  const pattern = /^[a-zA-Z0-9][a-zA-Z0-9-]*$/;
  return pattern.test(name) && name.length >= 3;
};

const getFullStoreUrl = storeName => {
  return `${storeName}.myshopify.com`;
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

// Connection state message
const connectionStatusMessage = ref('');

const handleShopifyConnect = async () => {
  try {
    shopifyError.value = '';
    connectionStatusMessage.value = '';
    
    // Store adını doğrula
    if (!shopifyStoreUrl.value || !validateStoreName(shopifyStoreUrl.value)) {
      shopifyError.value = t('SIDEBAR.INTEGRATIONS.SHOPIFY.INVALID_STORE_NAME');
      return;
    }
    
    // Access key doğrula
    if (!shopifyAccessKey.value || shopifyAccessKey.value.trim().length === 0) {
      shopifyError.value = t('SIDEBAR.INTEGRATIONS.SHOPIFY.ACCESS_KEY_MESSAGE');
      return;
    }

    isConnectingShopify.value = true;
    const fullStoreUrl = getFullStoreUrl(shopifyStoreUrl.value);
    
    // 1. Önce bağlantıyı test et
    connectionStatusMessage.value = t('SIDEBAR.INTEGRATIONS.SHOPIFY.TESTING_CONNECTION');
    
    try {
      const testResponse = await shopifyAPI.testCredentials({
        shopDomain: fullStoreUrl,
        accessKey: shopifyAccessKey.value,
      });
      
      if (!testResponse.data?.success) {
        shopifyError.value = testResponse.data?.error || t('SIDEBAR.INTEGRATIONS.SHOPIFY.CONNECTION_ERROR');
        return;
      }
      
      // Test başarılı - mağaza bilgisini göster
      const shopName = testResponse.data?.shop?.name || fullStoreUrl;
      connectionStatusMessage.value = t('SIDEBAR.INTEGRATIONS.SHOPIFY.TEST_SUCCESS_SAVING', { shopName });
    } catch (testError) {
      const errorMessage = testError.response?.data?.error || testError.message || '';
      shopifyError.value = errorMessage || t('SIDEBAR.INTEGRATIONS.SHOPIFY.CONNECTION_ERROR');
      return;
    }
    
    // 2. Test başarılı, şimdi kaydet
    const { data } = await shopifyAPI.connectWithAccessKey({
      shopDomain: fullStoreUrl,
      accessKey: shopifyAccessKey.value,
    });

    // Update hook data from response
    const hookData = data?.hook || data;

    if (hookData && (hookData.id || hookData.reference_id)) {
      shopifyHook.value = {
        id: hookData.id,
        reference_id: hookData.reference_id,
        enabled: hookData.enabled !== false,
        settings: hookData.settings || {},
      };
      integrations.value = [
        {
          id: 'shopify',
          enabled: shopifyHook.value.enabled,
          reference_id: shopifyHook.value.reference_id,
        },
      ];
      
      // allIntegrations'ı güncelle
      const shopifyIntegration = allIntegrations.value.find(i => i.id === 'shopify');
      if (shopifyIntegration) {
        shopifyIntegration.connected = true;
        shopifyIntegration.hook = shopifyHook.value;
      }
    } else {
      // Fallback to fetch if response format is different
      await fetchIntegrations();
    }

    useAlert(t('SIDEBAR.INTEGRATIONS.SHOPIFY.CONNECT_SUCCESS'), 'success');
    if (shopifyDialogRef.value) {
      shopifyDialogRef.value.close();
    }
    
    // İlk bağlantıda otomatik ürün senkronizasyonu başlat
    syncStatus.value = {
      status: 'pending',
      synced_products: 0,
      total_products: 0,
      progress_percentage: 0
    };
    
    try {
      await shopifyAPI.syncProducts(false); // full sync
      useAlert(t('SIDEBAR.INTEGRATIONS.SHOPIFY.SYNC_STARTED'), 'info');
      // Polling başlat
      startSyncStatusPolling();
    } catch (syncError) {
      // Sync başlatılamazsa sadece uyarı göster, bağlantı başarılı
      // eslint-disable-next-line no-console
      console.error('[Shopify] Auto sync failed:', syncError);
    }
  } catch (error) {
    const errorMessage = error.response?.data?.error || error.message || '';
    
    // API'den gelen hata mesajına göre spesifik hata göster
    if (errorMessage.toLowerCase().includes('access') || 
        errorMessage.toLowerCase().includes('token') ||
        errorMessage.toLowerCase().includes('unauthorized') ||
        errorMessage.toLowerCase().includes('erişim') ||
        error.response?.status === 401) {
      shopifyError.value = t('SIDEBAR.INTEGRATIONS.SHOPIFY.INVALID_ACCESS_KEY');
    } else if (errorMessage.toLowerCase().includes('store') ||
               errorMessage.toLowerCase().includes('shop') ||
               errorMessage.toLowerCase().includes('domain') ||
               errorMessage.toLowerCase().includes('mağaza') ||
               error.response?.status === 404) {
      shopifyError.value = t('SIDEBAR.INTEGRATIONS.SHOPIFY.INVALID_STORE_NAME');
    } else {
      shopifyError.value = errorMessage || t('SIDEBAR.INTEGRATIONS.SHOPIFY.CONNECTION_ERROR');
    }
  } finally {
    isConnectingShopify.value = false;
    connectionStatusMessage.value = '';
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

// Order Query Toggle Handler
const handleOrderQueryToggle = async () => {
  if (isUpdatingSettings.value) return;
  isUpdatingSettings.value = true;
  
  const newValue = orderQueryEnabled.value;
  
  try {
    await shopifyAPI.updateSettings({ order_query_enabled: newValue });
    
    if (shopifyHook.value) {
      shopifyHook.value.settings = {
        ...shopifyHook.value.settings,
        order_query_enabled: newValue,
      };
    }
    
    useAlert(
      newValue
        ? t('SIDEBAR.INTEGRATIONS.SHOPIFY.ORDER_QUERY.ENABLED')
        : t('SIDEBAR.INTEGRATIONS.SHOPIFY.ORDER_QUERY.DISABLED'),
      'success'
    );
  } catch (error) {
    orderQueryEnabled.value = !newValue;
    useAlert(t('SIDEBAR.INTEGRATIONS.SHOPIFY.SETTINGS_UPDATE_ERROR'), 'error');
  } finally {
    isUpdatingSettings.value = false;
  }
};

// Product Query Toggle Handler
const handleProductQueryToggle = async () => {
  if (isUpdatingSettings.value) return;
  isUpdatingSettings.value = true;
  
  const newValue = productQueryEnabled.value;
  
  try {
    await shopifyAPI.updateSettings({ product_query_enabled: newValue });
    
    if (shopifyHook.value) {
      shopifyHook.value.settings = {
        ...shopifyHook.value.settings,
        product_query_enabled: newValue,
      };
    }
    
    useAlert(
      newValue
        ? t('SIDEBAR.INTEGRATIONS.SHOPIFY.PRODUCT_QUERY.ENABLED')
        : t('SIDEBAR.INTEGRATIONS.SHOPIFY.PRODUCT_QUERY.DISABLED'),
      'success'
    );
  } catch (error) {
    productQueryEnabled.value = !newValue;
    useAlert(t('SIDEBAR.INTEGRATIONS.SHOPIFY.SETTINGS_UPDATE_ERROR'), 'error');
  } finally {
    isUpdatingSettings.value = false;
  }
};

// Image Search Toggle Handler
const handleImageSearchToggle = async () => {
  if (isUpdatingSettings.value) return;
  isUpdatingSettings.value = true;
  
  const newValue = imageSearchEnabled.value;
  
  try {
    await shopifyAPI.updateSettings({ image_search_enabled: newValue });
    
    if (shopifyHook.value) {
      shopifyHook.value.settings = {
        ...shopifyHook.value.settings,
        image_search_enabled: newValue,
      };
    }
    
    useAlert(
      newValue
        ? t('SIDEBAR.INTEGRATIONS.SHOPIFY.IMAGE_SEARCH.ENABLED_SUCCESS')
        : t('SIDEBAR.INTEGRATIONS.SHOPIFY.IMAGE_SEARCH.DISABLED_SUCCESS'),
      'success'
    );
  } catch (error) {
    imageSearchEnabled.value = !newValue;
    useAlert(t('SIDEBAR.INTEGRATIONS.SHOPIFY.IMAGE_SEARCH.UPDATE_ERROR'), 'error');
  } finally {
    isUpdatingSettings.value = false;
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
      <div class="flex flex-col gap-6 max-w-4xl mx-auto">
        <!-- Integration Cards -->
        <div
          v-for="integration in allIntegrations"
          :key="integration.id"
          class="bg-n-slate-1 border border-n-slate-4 rounded-xl overflow-hidden transition-all duration-200"
          :class="{
            'hover:border-n-slate-6 hover:shadow-lg cursor-pointer':
              !integration.comingSoon && !integration.connected,
            'opacity-60': integration.comingSoon,
          }"
          @click="handleIntegrationClick(integration)"
        >
          <!-- Card Header -->
          <div class="p-5 flex items-center gap-4">
            <!-- Logo -->
            <div
              class="w-14 h-14 rounded-xl flex items-center justify-center flex-shrink-0"
              :class="integration.connected ? 'bg-n-teal-3' : 'bg-n-slate-3'"
            >
              <Icon :icon="integration.icon" class="w-9 h-9" />
            </div>

            <!-- Info -->
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2">
                <h3 class="text-lg font-semibold text-n-slate-12">
                  {{ integration.name }}
                </h3>
                <span
                  v-if="integration.connected"
                  class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium bg-n-teal-3 text-n-teal-11"
                >
                  <Icon icon="i-lucide-check-circle" class="w-3 h-3" />
                  {{ $t('SIDEBAR.INTEGRATIONS.CONNECTED') }}
                </span>
                <span
                  v-if="integration.comingSoon"
                  class="px-2 py-0.5 rounded-full text-xs font-medium bg-n-amber-3 text-n-amber-11"
                >
                  {{ $t('SIDEBAR.INTEGRATIONS.COMING_SOON') }}
                </span>
              </div>
              <p class="text-sm text-n-slate-11 mt-0.5">
                {{ integration.description }}
              </p>
            </div>

            <!-- Actions -->
            <div
              v-if="integration.connected && !integration.comingSoon"
              class="flex items-center gap-2"
            >
              <button
                type="button"
                class="flex items-center gap-2 px-3 py-2 rounded-lg text-sm font-medium transition-colors"
                :class="{
                  'bg-n-teal-3 text-n-teal-11': connectionTestStatus[integration.id] === 'success',
                  'bg-n-ruby-3 text-n-ruby-11': connectionTestStatus[integration.id] === 'error',
                  'bg-n-slate-3 text-n-slate-11 hover:bg-n-slate-4': !connectionTestStatus[integration.id],
                }"
                :disabled="isTestingConnection[integration.id]"
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
                <Icon v-else icon="i-lucide-wifi" class="w-4 h-4" />
                {{ $t('SIDEBAR.INTEGRATIONS.TEST_CONNECTION') }}
              </button>
              <button
                type="button"
                class="flex items-center justify-center w-9 h-9 rounded-lg bg-n-slate-3 text-n-slate-11 hover:bg-n-slate-4 transition-colors"
                :title="$t('SIDEBAR.INTEGRATIONS.EDIT')"
                @click.stop="handleEditIntegration(integration)"
              >
                <Icon icon="i-lucide-settings" class="w-4 h-4" />
              </button>
              <button
                type="button"
                class="flex items-center justify-center w-9 h-9 rounded-lg bg-n-ruby-3 text-n-ruby-11 hover:bg-n-ruby-4 transition-colors"
                :title="$t('SIDEBAR.INTEGRATIONS.DISCONNECT')"
                @click.stop="handleDisconnectIntegration(integration)"
              >
                <Icon icon="i-lucide-unplug" class="w-4 h-4" />
              </button>
            </div>
            <div v-else-if="!integration.comingSoon" class="flex-shrink-0">
              <div class="flex items-center gap-2 px-4 py-2 rounded-lg bg-n-brand text-white text-sm font-medium">
                <Icon icon="i-lucide-plug" class="w-4 h-4" />
                {{ $t('SIDEBAR.INTEGRATIONS.CONNECT') }}
              </div>
            </div>
          </div>

          <!-- Connected Integration Details -->
          <div
            v-if="integration.connected && integration.hook?.reference_id"
            class="border-t border-n-slate-4"
          >
            <!-- Stats Row -->
            <div class="px-5 py-4 bg-n-alpha-1 flex items-center gap-6 flex-wrap">
              <!-- Store Info -->
              <div class="flex items-center gap-2">
                <Icon icon="i-lucide-store" class="w-4 h-4 text-n-slate-10" />
                <span class="text-sm text-n-slate-11">
                  {{ integration.hook.reference_id }}
                </span>
              </div>

              <!-- Product Count -->
              <div
                v-if="integration.id === 'shopify' && totalSyncedProducts > 0"
                class="flex items-center gap-2"
              >
                <Icon icon="i-lucide-package" class="w-4 h-4 text-n-blue-11" />
                <span class="text-sm font-medium text-n-blue-11">
                  {{ totalSyncedProducts.toLocaleString() }} {{ $t('SIDEBAR.INTEGRATIONS.SHOPIFY.PRODUCTS') }}
                </span>
              </div>

              <!-- Sync Status -->
              <div
                v-if="integration.id === 'shopify'"
                class="flex items-center gap-2"
              >
                <Icon
                  v-if="isSyncInProgress"
                  icon="i-lucide-loader-2"
                  class="w-4 h-4 animate-spin text-n-blue-11"
                />
                <Icon
                  v-else-if="syncStatus?.status === 'completed' || totalSyncedProducts > 0"
                  icon="i-lucide-check-circle-2"
                  class="w-4 h-4 text-n-teal-11"
                />
                <Icon
                  v-else-if="syncStatus?.status === 'failed'"
                  icon="i-lucide-alert-circle"
                  class="w-4 h-4 text-n-ruby-11"
                />
                <span
                  class="text-sm"
                  :class="{
                    'text-n-amber-11': syncStatus?.status === 'pending',
                    'text-n-blue-11': syncStatus?.status === 'syncing',
                    'text-n-teal-11': syncStatus?.status === 'completed' || (!syncStatus && totalSyncedProducts > 0),
                    'text-n-ruby-11': syncStatus?.status === 'failed',
                    'text-n-slate-11': !syncStatus && totalSyncedProducts === 0,
                  }"
                >
                  {{ syncStatusText }}
                </span>
              </div>

              <!-- Last Sync -->
              <div
                v-if="integration.id === 'shopify' && syncStatus?.completed_at"
                class="flex items-center gap-2 ml-auto"
              >
                <Icon icon="i-lucide-clock" class="w-4 h-4 text-n-slate-10" />
                <span class="text-sm text-n-slate-10">
                  {{ $t('SIDEBAR.INTEGRATIONS.SHOPIFY.LAST_SYNC') }}: {{ formatDate(syncStatus.completed_at) }}
                </span>
              </div>

              <!-- Sync Button -->
              <button
                v-if="integration.id === 'shopify'"
                class="flex items-center gap-2 px-3 py-1.5 text-sm font-medium rounded-lg transition-colors ml-auto"
                :class="{
                  'text-n-blue-11 bg-n-blue-3 hover:bg-n-blue-4': !isSyncInProgress,
                  'text-n-slate-11 bg-n-slate-3 cursor-not-allowed': isSyncInProgress,
                }"
                :disabled="isSyncInProgress"
                @click.stop="handleResync"
              >
                <Icon
                  :icon="isSyncInProgress ? 'i-lucide-loader-2' : 'i-lucide-refresh-cw'"
                  :class="{ 'animate-spin': isSyncInProgress }"
                  class="w-4 h-4"
                />
                {{ isSyncInProgress ? $t('SIDEBAR.INTEGRATIONS.SHOPIFY.SYNCING') : $t('SIDEBAR.INTEGRATIONS.SHOPIFY.RESYNC_PRODUCTS') }}
              </button>
            </div>

            <!-- Progress Bar (when syncing) -->
            <div
              v-if="integration.id === 'shopify' && syncStatus && (syncStatus.status === 'syncing' || syncStatus.status === 'pending')"
              class="px-5 pb-4 bg-n-alpha-1"
            >
              <div class="w-full bg-n-slate-3 rounded-full h-1.5 overflow-hidden">
                <div
                  class="h-full bg-n-blue-9 transition-all duration-300"
                  :style="{ width: `${syncStatus.progress_percentage || 0}%` }"
                />
              </div>
              <p v-if="syncStatus.total_products > 0" class="text-xs text-n-slate-11 mt-1.5">
                {{ $t('SIDEBAR.INTEGRATIONS.SHOPIFY.SYNC_PROGRESS', {
                  synced: syncStatus.synced_products || 0,
                  total: syncStatus.total_products,
                  percentage: Math.round(syncStatus.progress_percentage || 0),
                }) }}
              </p>
            </div>

            <!-- Error Message -->
            <div
              v-if="integration.id === 'shopify' && syncStatus?.status === 'failed' && syncStatus?.error_message"
              class="px-5 pb-4 bg-n-alpha-1"
            >
              <div class="flex items-center gap-2 p-3 rounded-lg bg-n-ruby-3 text-n-ruby-11 text-sm">
                <Icon icon="i-lucide-alert-triangle" class="w-4 h-4 flex-shrink-0" />
                {{ syncStatus.error_message }}
              </div>
            </div>

            <!-- AI Features Section (only for Shopify) -->
            <div v-if="integration.id === 'shopify'" class="p-5 bg-n-alpha-1 border-t border-n-slate-4">
              <div class="flex items-center gap-2 mb-4">
                <Icon icon="i-lucide-sparkles" class="w-5 h-5 text-n-violet-11" />
                <h4 class="text-sm font-semibold text-n-slate-12">
                  {{ $t('SIDEBAR.INTEGRATIONS.SHOPIFY.AI_FEATURES.TITLE') }}
                </h4>
              </div>

              <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
                <!-- Order Query Toggle -->
                <div class="flex items-center justify-between gap-3 p-4 bg-n-slate-2 rounded-xl border border-n-slate-4">
                  <div class="flex items-center gap-3">
                    <div class="w-10 h-10 bg-n-blue-3 rounded-lg flex items-center justify-center flex-shrink-0">
                      <Icon icon="i-lucide-shopping-bag" class="w-5 h-5 text-n-blue-11" />
                    </div>
                    <div>
                      <span class="text-sm font-medium text-n-slate-12 block">
                        {{ $t('SIDEBAR.INTEGRATIONS.SHOPIFY.ORDER_QUERY.TITLE') }}
                      </span>
                      <span class="text-xs text-n-slate-10">
                        {{ $t('SIDEBAR.INTEGRATIONS.SHOPIFY.ORDER_QUERY.DESCRIPTION') }}
                      </span>
                    </div>
                  </div>
                  <Switch
                    v-model="orderQueryEnabled"
                    :disabled="isUpdatingSettings"
                    @change="handleOrderQueryToggle"
                  />
                </div>

                <!-- Product Query Toggle -->
                <div class="flex items-center justify-between gap-3 p-4 bg-n-slate-2 rounded-xl border border-n-slate-4">
                  <div class="flex items-center gap-3">
                    <div class="w-10 h-10 bg-n-amber-3 rounded-lg flex items-center justify-center flex-shrink-0">
                      <Icon icon="i-lucide-package-search" class="w-5 h-5 text-n-amber-11" />
                    </div>
                    <div>
                      <span class="text-sm font-medium text-n-slate-12 block">
                        {{ $t('SIDEBAR.INTEGRATIONS.SHOPIFY.PRODUCT_QUERY.TITLE') }}
                      </span>
                      <span class="text-xs text-n-slate-10">
                        {{ $t('SIDEBAR.INTEGRATIONS.SHOPIFY.PRODUCT_QUERY.DESCRIPTION') }}
                      </span>
                    </div>
                  </div>
                  <Switch
                    v-model="productQueryEnabled"
                    :disabled="isUpdatingSettings"
                    @change="handleProductQueryToggle"
                  />
                </div>

                <!-- Image Search Toggle -->
                <div class="flex items-center justify-between gap-3 p-4 bg-n-slate-2 rounded-xl border border-n-slate-4">
                  <div class="flex items-center gap-3">
                    <div class="w-10 h-10 bg-n-violet-3 rounded-lg flex items-center justify-center flex-shrink-0">
                      <Icon icon="i-lucide-image-search" class="w-5 h-5 text-n-violet-11" />
                    </div>
                    <div>
                      <span class="text-sm font-medium text-n-slate-12 block">
                        {{ $t('SIDEBAR.INTEGRATIONS.SHOPIFY.IMAGE_SEARCH.TITLE') }}
                      </span>
                      <span class="text-xs text-n-slate-10">
                        {{ $t('SIDEBAR.INTEGRATIONS.SHOPIFY.IMAGE_SEARCH.DESCRIPTION') }}
                      </span>
                    </div>
                  </div>
                  <Switch
                    v-model="imageSearchEnabled"
                    :disabled="isUpdatingSettings"
                    @change="handleImageSearchToggle"
                  />
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
        <div>
          <label class="block text-sm font-medium text-n-slate-12 mb-1">
            {{ $t('SIDEBAR.INTEGRATIONS.SHOPIFY.STORE_URL_LABEL') }}
          </label>
          <div class="flex items-center">
            <input
              v-model="shopifyStoreUrl"
              type="text"
              class="flex-1 px-3 py-2 border border-n-weak rounded-l-lg focus:outline-none focus:ring-2 focus:ring-n-brand focus:border-transparent bg-n-alpha-1 text-n-slate-12"
              :placeholder="$t('SIDEBAR.INTEGRATIONS.SHOPIFY.STORE_NAME_PLACEHOLDER')"
              @input="shopifyError = ''"
            />
            <!-- eslint-disable-next-line vue/no-bare-strings-in-template -->
            <span class="px-3 py-2 bg-n-alpha-3 border border-l-0 border-n-weak rounded-r-lg text-n-slate-11 text-sm whitespace-nowrap">.myshopify.com</span>
          </div>
          <p
            v-if="shopifyError && (shopifyError.includes('mağaza') || shopifyError.includes('store'))"
            class="mt-1 text-sm text-n-ruby-9"
          >
            {{ shopifyError }}
          </p>
          <p v-else class="mt-1 text-sm text-n-slate-11">
            {{ $t('SIDEBAR.INTEGRATIONS.SHOPIFY.STORE_NAME_MESSAGE') }}
          </p>
        </div>
        <Input
          v-model="shopifyAccessKey"
          :label="$t('SIDEBAR.INTEGRATIONS.SHOPIFY.ACCESS_KEY_LABEL')"
          type="password"
          :placeholder="$t('SIDEBAR.INTEGRATIONS.SHOPIFY.ACCESS_KEY_PLACEHOLDER')"
          :message="
            shopifyError && (shopifyError.includes('Access') || shopifyError.includes('key') || shopifyError.includes('anahtar') || shopifyError.includes('Erişim'))
              ? shopifyError
              : $t('SIDEBAR.INTEGRATIONS.SHOPIFY.ACCESS_KEY_MESSAGE')
          "
          :message-type="
            shopifyError && (shopifyError.includes('Access') || shopifyError.includes('key') || shopifyError.includes('anahtar') || shopifyError.includes('Erişim')) ? 'error' : 'info'
          "
          @input="shopifyError = ''"
        />
        
        <!-- Connection Status Message -->
        <div
          v-if="connectionStatusMessage"
          class="flex items-center gap-2 p-3 rounded-lg bg-n-alpha-2"
        >
          <div class="animate-spin">
            <Icon icon="i-lucide-loader-2" class="w-4 h-4 text-n-brand" />
          </div>
          <span class="text-sm text-n-slate-11">{{ connectionStatusMessage }}</span>
        </div>
        
        <!-- General Error Message -->
        <div
          v-if="shopifyError && !shopifyError.includes('mağaza') && !shopifyError.includes('store') && !shopifyError.includes('Access') && !shopifyError.includes('key') && !shopifyError.includes('anahtar') && !shopifyError.includes('Erişim')"
          class="flex items-center gap-2 p-3 rounded-lg bg-n-ruby-3"
        >
          <Icon icon="i-lucide-alert-circle" class="w-4 h-4 text-n-ruby-9" />
          <span class="text-sm text-n-ruby-11">{{ shopifyError }}</span>
        </div>
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

    <!-- Disconnect Confirmation Dialog -->
    <Dialog
      ref="disconnectDialogRef"
      :title="$t('SIDEBAR.INTEGRATIONS.SHOPIFY.DISCONNECT_DIALOG.TITLE')"
      :confirm-text="$t('SIDEBAR.INTEGRATIONS.SHOPIFY.DISCONNECT_DIALOG.CONFIRM')"
      :cancel-text="$t('SIDEBAR.INTEGRATIONS.SHOPIFY.DISCONNECT_DIALOG.CANCEL')"
      :is-loading="isDisconnecting"
      confirm-variant="danger"
      @confirm="handleConfirmDisconnect"
      @close="() => { disconnectIntegration = null; }"
    >
      <div class="space-y-4">
        <!-- Warning Icon -->
        <div class="flex items-center justify-center">
          <div class="w-16 h-16 bg-n-ruby-3 rounded-full flex items-center justify-center">
            <Icon icon="i-lucide-alert-triangle" class="w-8 h-8 text-n-ruby-11" />
          </div>
        </div>
        
        <!-- Warning Message -->
        <div class="text-center space-y-2">
          <p class="text-n-slate-12 font-medium">
            {{ $t('SIDEBAR.INTEGRATIONS.SHOPIFY.DISCONNECT_DIALOG.WARNING') }}
          </p>
          <p class="text-sm text-n-slate-11">
            {{ $t('SIDEBAR.INTEGRATIONS.SHOPIFY.DISCONNECT_DIALOG.DESCRIPTION') }}
          </p>
        </div>
        
        <!-- Impact List -->
        <div class="bg-n-ruby-2 border border-n-ruby-6 p-4 rounded-lg">
          <h4 class="font-medium text-n-ruby-11 mb-2">
            {{ $t('SIDEBAR.INTEGRATIONS.SHOPIFY.DISCONNECT_DIALOG.IMPACT_TITLE') }}
          </h4>
          <ul class="space-y-2 text-sm text-n-ruby-11">
            <li class="flex items-start gap-2">
              <Icon icon="i-lucide-trash-2" class="w-4 h-4 mt-0.5" />
              <span>
                {{ $t('SIDEBAR.INTEGRATIONS.SHOPIFY.DISCONNECT_DIALOG.IMPACT_PRODUCTS', { count: totalSyncedProducts }) }}
              </span>
            </li>
            <li class="flex items-start gap-2">
              <Icon icon="i-lucide-bot" class="w-4 h-4 mt-0.5" />
              <span>{{ $t('SIDEBAR.INTEGRATIONS.SHOPIFY.DISCONNECT_DIALOG.IMPACT_ASSISTANT') }}</span>
            </li>
            <li class="flex items-start gap-2">
              <Icon icon="i-lucide-image-off" class="w-4 h-4 mt-0.5" />
              <span>{{ $t('SIDEBAR.INTEGRATIONS.SHOPIFY.DISCONNECT_DIALOG.IMPACT_IMAGE_SEARCH') }}</span>
            </li>
          </ul>
        </div>
        
        <!-- Store Info -->
        <div v-if="disconnectIntegration?.hook?.reference_id" class="text-center">
          <p class="text-xs text-n-slate-10">
            {{ $t('SIDEBAR.INTEGRATIONS.SHOPIFY.DISCONNECT_DIALOG.STORE_LABEL') }}
            <span class="font-medium text-n-slate-11">{{ disconnectIntegration.hook.reference_id }}</span>
          </p>
        </div>
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

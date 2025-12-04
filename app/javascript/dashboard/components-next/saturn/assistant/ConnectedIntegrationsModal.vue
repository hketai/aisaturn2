<script setup>
import { ref, computed, onMounted } from 'vue';
import { useAlert } from 'dashboard/composables';
import { useRouter } from 'vue-router';
import shopifyAPI from 'dashboard/api/integrations/shopify';
import assistantIntegrationsAPI from 'dashboard/api/saturn/assistantIntegrations';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';

const props = defineProps({
  assistantId: {
    type: Number,
    required: true,
  },
  assistantName: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['close', 'updated']);
const router = useRouter();

const dialogRef = ref(null);
const isLoading = ref(false);
const isSaving = ref(false);
const integrations = ref([]);
const assistantEnabledIntegrations = ref([]);

// Available integrations list
const availableIntegrations = [
  {
    id: 'shopify',
    name: 'Shopify',
    description: 'Mağaza ürünlerini sorgulama',
    icon: 'i-logos-shopify',
    accountConnected: false,
    assistantEnabled: false,
  },
];

// Fetch account integrations and assistant settings
const fetchIntegrations = async () => {
  isLoading.value = true;
  try {
    // Check if Shopify is connected at account level
    let shopifyConnected = false;
    let shopifyReferenceId = null;
    
    try {
      const shopifyResponse = await shopifyAPI.getHook();
      const shopifyHook = shopifyResponse.data?.hook || shopifyResponse.hook;
      shopifyConnected = !!shopifyHook?.id;
      shopifyReferenceId = shopifyHook?.reference_id;
    } catch {
      // Shopify not connected at account level
    }

    // Fetch assistant's integration settings
    try {
      const assistantResponse = await assistantIntegrationsAPI.getIntegrations(props.assistantId);
      assistantEnabledIntegrations.value = assistantResponse.data?.enabled_integrations || [];
    } catch {
      assistantEnabledIntegrations.value = [];
    }
    
    integrations.value = availableIntegrations.map(integration => {
      if (integration.id === 'shopify') {
        return {
          ...integration,
          accountConnected: shopifyConnected,
          referenceId: shopifyReferenceId,
          assistantEnabled: assistantEnabledIntegrations.value.includes('shopify'),
        };
      }
      return integration;
    });
  } catch (error) {
    integrations.value = availableIntegrations;
  } finally {
    isLoading.value = false;
  }
};

const handleConnectIntegration = integration => {
  if (integration.id === 'shopify') {
    router.push({ name: 'saturn_integrations_index' });
    dialogRef.value.close();
  }
};

const handleToggleIntegration = async (integration) => {
  if (!integration.accountConnected) {
    useAlert('Önce hesap düzeyinde entegrasyonu bağlamanız gerekiyor.', 'warning');
    return;
  }

  isSaving.value = true;
  try {
    const newEnabled = !integration.assistantEnabled;
    await assistantIntegrationsAPI.toggleIntegration(
      props.assistantId,
      integration.id,
      newEnabled
    );
    
    // Update local state
    const idx = integrations.value.findIndex(i => i.id === integration.id);
    if (idx !== -1) {
      integrations.value[idx].assistantEnabled = newEnabled;
    }
    
    useAlert(
      newEnabled 
        ? `${integration.name} bu asistan için aktif edildi.`
        : `${integration.name} bu asistan için devre dışı bırakıldı.`,
      'success'
    );
    
    emit('updated');
  } catch (error) {
    useAlert('Entegrasyon durumu güncellenirken bir hata oluştu.', 'error');
  } finally {
    isSaving.value = false;
  }
};

const handleClose = () => {
  emit('close');
};

onMounted(() => {
  fetchIntegrations();
});

defineExpose({ dialogRef });
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="edit"
    title="Entegrasyonlar"
    :description="`${assistantName} için entegrasyon yönetimi`"
    :show-cancel-button="false"
    :show-confirm-button="false"
    overflow-y-auto
    @close="handleClose"
  >
    <div class="flex flex-col gap-4 py-2">
      <!-- Loading State -->
      <div v-if="isLoading" class="flex items-center justify-center py-8">
        <i class="i-lucide-loader-2 size-6 animate-spin text-n-slate-11" />
      </div>

      <!-- Integrations List -->
      <div v-else class="flex flex-col gap-3">
        <p class="text-xs text-n-slate-11">
          Bu asistan için entegrasyonları aktif veya pasif yapabilirsiniz.
          Entegrasyon aktifse, asistan ilgili verilere erişebilir.
        </p>

        <div
          v-for="integration in integrations"
          :key="integration.id"
          class="flex items-center gap-4 p-4 rounded-lg border transition-all"
          :class="{
            'bg-n-solid-2 border-n-weak': !integration.accountConnected,
            'bg-n-teal-2 border-n-teal-6': integration.accountConnected && integration.assistantEnabled,
            'bg-n-slate-2 border-n-slate-5': integration.accountConnected && !integration.assistantEnabled,
          }"
        >
          <div
            class="size-12 flex items-center justify-center rounded-lg"
            :class="{
              'bg-n-slate-3': !integration.accountConnected,
              'bg-n-teal-3': integration.accountConnected && integration.assistantEnabled,
              'bg-n-slate-4': integration.accountConnected && !integration.assistantEnabled,
            }"
          >
            <Icon :icon="integration.icon" class="size-8" />
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-sm font-medium text-n-slate-12">
              {{ integration.name }}
            </p>
            <p class="text-xs text-n-slate-11 mt-0.5">
              {{ integration.description }}
            </p>
            <!-- Account Connection Status -->
            <p
              v-if="integration.accountConnected && integration.referenceId"
              class="text-xs text-n-teal-11 mt-1"
            >
              <i class="i-lucide-check-circle size-3 inline mr-1" />
              {{ integration.referenceId }}
            </p>
            <p
              v-else-if="!integration.accountConnected"
              class="text-xs text-n-amber-11 mt-1"
            >
              <i class="i-lucide-alert-circle size-3 inline mr-1" />
              Hesap düzeyinde bağlı değil
            </p>
          </div>
          
          <!-- Connect Button (if not connected at account level) -->
          <Button
            v-if="!integration.accountConnected"
            xs
            @click="handleConnectIntegration(integration)"
          >
            Bağlan
          </Button>
          
          <!-- Toggle Switch (if connected at account level) -->
          <div v-else class="flex items-center gap-2">
            <span 
              class="text-xs font-medium"
              :class="{
                'text-n-teal-11': integration.assistantEnabled,
                'text-n-slate-10': !integration.assistantEnabled,
              }"
            >
              {{ integration.assistantEnabled ? 'Aktif' : 'Pasif' }}
            </span>
            <Switch
              :model-value="integration.assistantEnabled"
              :disabled="isSaving"
              @change="handleToggleIntegration(integration)"
            />
          </div>
        </div>

        <!-- Info Message -->
        <div class="flex items-start gap-2 p-3 rounded-lg bg-n-blue-2 border border-n-blue-6 mt-2">
          <i class="i-lucide-info size-4 text-n-blue-11 flex-shrink-0 mt-0.5" />
          <p class="text-xs text-n-blue-11">
            Entegrasyonlar hesap düzeyinde bağlanır, ancak her asistan için ayrı ayrı aktif/pasif yapılabilir.
            Örneğin, "Satış Asistanı" için Shopify açık, "Destek Asistanı" için kapalı olabilir.
          </p>
        </div>
      </div>
    </div>

    <template #footer>
      <div class="flex items-center justify-end w-full">
        <Button
          variant="faded"
          color="slate"
          label="Kapat"
          @click="dialogRef.close()"
        />
      </div>
    </template>
  </Dialog>
</template>

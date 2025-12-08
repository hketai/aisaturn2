<script setup>
/* eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text */
import { ref, onMounted, computed } from 'vue';
import subscriptionPlansAPI from 'dashboard/api/subscriptionPlans';
import subscriptionsAPI from 'dashboard/api/subscriptions';
import Button from 'dashboard/components-next/button/Button.vue';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';

const plans = ref([]);
const currentSubscription = ref(null);
const limits = ref(null);
const loading = ref(false);
const error = ref(null);

const fetchPlans = async () => {
  try {
    const response = await subscriptionPlansAPI.get();
    // API returns array directly, not wrapped in data
    plans.value = Array.isArray(response.data) ? response.data : [];
  } catch (err) {
    error.value = err.message || 'Planlar yüklenemedi';
  }
};

const fetchCurrentSubscription = async () => {
  try {
    const response = await subscriptionsAPI.current();
    currentSubscription.value = response.data;
  } catch (err) {
    if (err.response?.status !== 404) {
      error.value = err.message;
    }
  }
};

const fetchLimits = async () => {
  try {
    const response = await subscriptionsAPI.limits();
    limits.value = response.data;
  } catch (err) {
    error.value = err.message;
  }
};

const subscribeToPlan = async planId => {
  loading.value = true;
  try {
    await subscriptionsAPI.create({
      subscription_plan_id: planId,
      options: {
        auto_renew: true,
      },
    });
    await fetchCurrentSubscription();
    await fetchLimits();
  } catch (err) {
    error.value = err.message || 'Abonelik oluşturulamadı';
  } finally {
    loading.value = false;
  }
};

const cancelSubscription = async (subscriptionId, immediate = false) => {
  // eslint-disable-next-line no-alert, no-restricted-globals
  if (!window.confirm('Aboneliği iptal etmek istediğinizden emin misiniz?')) {
    return;
  }

  loading.value = true;
  try {
    await subscriptionsAPI.cancel(subscriptionId, immediate);
    await fetchCurrentSubscription();
    await fetchLimits();
  } catch (err) {
    error.value = err.message || 'Abonelik iptal edilemedi';
  } finally {
    loading.value = false;
  }
};

const upgradePlan = async planId => {
  loading.value = true;
  try {
    await subscriptionsAPI.update(currentSubscription.value.id, {
      subscription_plan_id: planId,
      options: {
        cancel_existing: true,
      },
    });
    await fetchCurrentSubscription();
    await fetchLimits();
  } catch (err) {
    error.value = err.message || 'Plan yükseltilemedi';
  } finally {
    loading.value = false;
  }
};

const formatPrice = price => {
  return new Intl.NumberFormat('tr-TR', {
    style: 'currency',
    currency: 'TRY',
  }).format(price);
};

const formatLimit = limit => {
  return limit === 0 ? 'Sınırsız' : limit.toLocaleString('tr-TR');
};

const getUsagePercentage = limitData => {
  if (limitData.limit === 0) return 0; // Unlimited
  if (limitData.current === 0) return 0;
  const percentage = (limitData.current / limitData.limit) * 100;
  return Math.min(percentage, 100); // Cap at 100%
};

// Eğer mevcut aboneliğin planı aktif planlar listesinde yoksa (gizli plan),
// onu da görüntüleme için ekle
const displayPlans = computed(() => {
  const currentPlan = currentSubscription.value?.plan;
  if (!currentPlan) return plans.value;

  const planExists = plans.value.some(p => p.id === currentPlan.id);
  if (planExists) return plans.value;

  // Gizli planı listeye ekle (isHidden flag'i ile)
  return [...plans.value, { ...currentPlan, isHidden: true }];
});

onMounted(async () => {
  loading.value = true;
  try {
    await Promise.all([
      fetchPlans(),
      fetchCurrentSubscription(),
      fetchLimits(),
    ]);
  } catch (err) {
    error.value = err.message || 'Veriler yüklenemedi';
  } finally {
    loading.value = false;
  }
});
</script>

<template>
  <SettingsLayout :is-loading="loading" class="max-w-6xl mx-auto w-full">
    <template #header>
      <BaseSettingsHeader
        title="Abonelik Yönetimi"
        description="Paket seçin ve aboneliğinizi yönetin"
      />
    </template>

    <template #body>
      <!-- Debug Info -->
      <div
        v-if="false"
        class="mb-4 p-4 bg-n-slate-3 border border-n-weak rounded-lg text-xs"
      >
        <p>Plans: {{ plans.length }}</p>
        <p>Current Subscription: {{ currentSubscription ? 'Yes' : 'No' }}</p>
        <p>Limits: {{ limits ? 'Yes' : 'No' }}</p>
        <p>Loading: {{ loading }}</p>
        <p>Error: {{ error }}</p>
      </div>

      <div
        v-if="error"
        class="mb-4 p-4 bg-n-ruby-3 border border-n-ruby-6 rounded-lg"
      >
        <p class="text-n-ruby-11">{{ error }}</p>
      </div>

      <!-- Mevcut Abonelik -->
      <div
        v-if="currentSubscription && currentSubscription.plan"
        class="mb-8 p-6 bg-n-slate-2 rounded-lg border border-n-weak shadow-sm"
      >
        <h2 class="text-xl font-semibold mb-4 text-n-slate-12">
          Mevcut Abonelik
        </h2>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
          <div>
            <p class="text-sm text-n-slate-11 mb-1">Plan</p>
            <p class="text-lg font-medium text-n-slate-12">
              {{ currentSubscription.plan?.name }}
            </p>
          </div>
          <div>
            <p class="text-sm text-n-slate-11 mb-1">Durum</p>
            <p class="text-lg font-medium">
              <span
                :class="{
                  'text-n-teal-11': currentSubscription.active,
                  'text-n-ruby-11': currentSubscription.canceled,
                  'text-n-amber-11': currentSubscription.trial,
                }"
              >
                {{
                  currentSubscription.active
                    ? 'Aktif'
                    : currentSubscription.canceled
                      ? 'İptal Edildi'
                      : 'Deneme'
                }}
              </span>
            </p>
          </div>
          <div v-if="currentSubscription.expires_at">
            <p class="text-sm text-n-slate-11 mb-1">Bitiş Tarihi</p>
            <p class="text-lg font-medium text-n-slate-12">
              {{
                new Date(currentSubscription.expires_at).toLocaleDateString(
                  'tr-TR'
                )
              }}
            </p>
          </div>
        </div>
        <div
          v-if="limits && limits.limits"
          class="mt-4 pt-4 border-t border-n-weak"
        >
          <h3 class="text-md font-semibold mb-4 text-n-slate-12">
            Kullanım Durumu
          </h3>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <div class="flex justify-between items-center mb-1">
                <p class="text-sm font-medium text-n-slate-11">Mesajlar</p>
                <p class="text-sm text-n-slate-12">
                  {{ limits.limits.messages.current }} /
                  {{ formatLimit(limits.limits.messages.limit) }}
                </p>
              </div>
              <div class="w-full bg-n-slate-4 rounded-full h-2">
                <div
                  class="h-2 rounded-full transition-all"
                  :class="{
                    'bg-n-teal-9':
                      getUsagePercentage(limits.limits.messages) < 80,
                    'bg-n-amber-9':
                      getUsagePercentage(limits.limits.messages) >= 80 &&
                      getUsagePercentage(limits.limits.messages) < 95,
                    'bg-n-ruby-9':
                      getUsagePercentage(limits.limits.messages) >= 95,
                  }"
                  :style="{
                    width: getUsagePercentage(limits.limits.messages) + '%',
                  }"
                />
              </div>
            </div>
            <div>
              <div class="flex justify-between items-center mb-1">
                <p class="text-sm font-medium text-n-slate-11">Konuşmalar</p>
                <p class="text-sm text-n-slate-12">
                  {{ limits.limits.conversations.current }} /
                  {{ formatLimit(limits.limits.conversations.limit) }}
                </p>
              </div>
              <div class="w-full bg-n-slate-4 rounded-full h-2">
                <div
                  class="h-2 rounded-full transition-all"
                  :class="{
                    'bg-n-teal-9':
                      getUsagePercentage(limits.limits.conversations) < 80,
                    'bg-n-amber-9':
                      getUsagePercentage(limits.limits.conversations) >= 80 &&
                      getUsagePercentage(limits.limits.conversations) < 95,
                    'bg-n-ruby-9':
                      getUsagePercentage(limits.limits.conversations) >= 95,
                  }"
                  :style="{
                    width:
                      getUsagePercentage(limits.limits.conversations) + '%',
                  }"
                />
              </div>
            </div>
            <div>
              <div class="flex justify-between items-center mb-1">
                <p class="text-sm font-medium text-n-slate-11">Ajanlar</p>
                <p class="text-sm text-n-slate-12">
                  {{ limits.limits.agents.current }} /
                  {{ formatLimit(limits.limits.agents.limit) }}
                </p>
              </div>
              <div class="w-full bg-n-slate-4 rounded-full h-2">
                <div
                  class="h-2 rounded-full transition-all"
                  :class="{
                    'bg-n-teal-9':
                      getUsagePercentage(limits.limits.agents) < 80,
                    'bg-n-amber-9':
                      getUsagePercentage(limits.limits.agents) >= 80 &&
                      getUsagePercentage(limits.limits.agents) < 95,
                    'bg-n-ruby-9':
                      getUsagePercentage(limits.limits.agents) >= 95,
                  }"
                  :style="{
                    width: getUsagePercentage(limits.limits.agents) + '%',
                  }"
                />
              </div>
            </div>
            <div>
              <div class="flex justify-between items-center mb-1">
                <p class="text-sm font-medium text-n-slate-11">Inbox'lar</p>
                <p class="text-sm text-n-slate-12">
                  {{ limits.limits.inboxes.current }} /
                  {{ formatLimit(limits.limits.inboxes.limit) }}
                </p>
              </div>
              <div class="w-full bg-n-slate-4 rounded-full h-2">
                <div
                  class="h-2 rounded-full transition-all"
                  :class="{
                    'bg-n-teal-9':
                      getUsagePercentage(limits.limits.inboxes) < 80,
                    'bg-n-amber-9':
                      getUsagePercentage(limits.limits.inboxes) >= 80 &&
                      getUsagePercentage(limits.limits.inboxes) < 95,
                    'bg-n-ruby-9':
                      getUsagePercentage(limits.limits.inboxes) >= 95,
                  }"
                  :style="{
                    width: getUsagePercentage(limits.limits.inboxes) + '%',
                  }"
                />
              </div>
            </div>
          </div>
        </div>
        <div v-if="currentSubscription.active" class="mt-4">
          <Button
            variant="faded"
            color="ruby"
            size="sm"
            label="Aboneliği İptal Et"
            @click="cancelSubscription(currentSubscription.id)"
          />
        </div>
      </div>

      <!-- Planlar -->
      <div>
        <h2 class="text-xl font-semibold mb-4 text-n-slate-12">
          Mevcut Planlar
        </h2>
        <div
          v-if="displayPlans.length > 0"
          class="grid grid-cols-1 md:grid-cols-3 gap-6"
        >
          <div
            v-for="plan in displayPlans"
            :key="plan.id"
            class="p-6 rounded-lg border shadow-sm hover:shadow-md transition-all relative"
            :class="{
              'bg-n-iris-2 border-n-iris-9 ring-2 ring-n-iris-9':
                currentSubscription?.plan?.id === plan.id,
              'bg-n-slate-2 border-n-weak hover:border-n-iris-6':
                currentSubscription?.plan?.id !== plan.id,
            }"
          >
            <div
              v-if="currentSubscription?.plan?.id === plan.id"
              class="absolute top-4 right-4 px-3 py-1 bg-n-iris-9 text-n-iris-1 text-xs font-semibold rounded-full"
            >
              Seçili Paket
            </div>
            <div
              v-if="plan.isHidden"
              class="absolute bottom-4 right-4 px-3 py-1 bg-n-amber-9 text-n-amber-1 text-xs font-semibold rounded-full"
            >
              Özel Plan
            </div>
            <h3 class="text-xl font-bold mb-2 text-n-slate-12">
              {{ plan.name }}
            </h3>
            <p class="text-n-slate-11 mb-4">{{ plan.description }}</p>
            <div class="mb-4">
              <span class="text-3xl font-bold text-n-slate-12">{{
                formatPrice(plan.price)
              }}</span>
              <span v-if="plan.billing_cycle" class="text-n-slate-11">
              / {{ plan.billing_cycle === 'monthly' ? 'ay' : 'yıl' }}
            </span>
            </div>
            <ul class="mb-6 space-y-2">
              <li class="flex items-center">
                <span class="text-sm text-n-slate-12">
                  Mesaj: {{ formatLimit(plan.message_limit) }}
                </span>
              </li>
              <li class="flex items-center">
                <span class="text-sm text-n-slate-12">
                  Konuşma: {{ formatLimit(plan.conversation_limit) }}
                </span>
              </li>
              <li class="flex items-center">
                <span class="text-sm text-n-slate-12">
                  Ajan: {{ formatLimit(plan.agent_limit || 0) }}
                </span>
              </li>
              <li class="flex items-center">
                <span class="text-sm text-n-slate-12">
                  Inbox: {{ formatLimit(plan.inbox_limit || 0) }}
                </span>
              </li>
            </ul>
            <!-- Gizli plan ise buton gösterme -->
            <Button
              v-if="currentSubscription?.plan?.id !== plan.id && !plan.isHidden"
              :label="currentSubscription ? 'Plan Değiştir' : 'Abone Ol'"
              :is-loading="loading"
              @click="
                currentSubscription
                  ? upgradePlan(plan.id)
                  : subscribeToPlan(plan.id)
              "
            />
            <div
              v-else-if="currentSubscription?.plan?.id === plan.id"
              class="text-center text-n-teal-11 font-semibold"
            >
              Aktif Plan
            </div>
          </div>
        </div>
        <div v-else-if="!loading" class="text-center py-8">
          <p class="text-n-slate-11">Henüz aktif plan bulunmamaktadır.</p>
        </div>
        <div v-else class="text-center py-8">
          <p class="text-n-slate-11">Planlar yükleniyor...</p>
        </div>
      </div>
    </template>
  </SettingsLayout>
</template>

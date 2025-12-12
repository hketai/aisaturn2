<script setup>
import { computed, ref } from 'vue';
import BarChart from 'shared/components/charts/BarChart.vue';

const props = defineProps({
  componentData: {
    type: Object,
    default: () => ({}),
  },
});

const selectedPeriod = ref('this_month');

const {
  summary,
  dailyTrend,
  accountUsage,
  modelUsage,
  assistantPerformance,
  systemHealth,
  stats,
} = props.componentData;

// Chart data preparation
const chartData = computed(() => {
  if (!dailyTrend || dailyTrend.length === 0) {
    return { labels: [], datasets: [] };
  }

  return {
    labels: dailyTrend.map(item => item[0]),
    datasets: [
      {
        type: 'bar',
        backgroundColor: 'rgb(99, 102, 241)',
        yAxisID: 'y',
        label: 'Günlük Maliyet ($)',
        data: dailyTrend.map(item => item[1]),
      },
    ],
  };
});

// Format helpers
const formatCurrency = value => {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: 2,
    maximumFractionDigits: 4,
  }).format(value || 0);
};

const formatNumber = value => {
  return new Intl.NumberFormat('tr-TR').format(value || 0);
};

const formatPercent = value => {
  return `${(value || 0).toFixed(1)}%`;
};

// Confidence distribution percentages
const confidencePercentages = computed(() => {
  const dist = summary?.quality?.confidence_distribution || {};
  const total = Object.values(dist).reduce((a, b) => a + b, 0);
  if (total === 0) return { high: 0, medium: 0, low: 0 };

  return {
    high: (((dist.high || 0) / total) * 100).toFixed(1),
    medium: (((dist.medium || 0) / total) * 100).toFixed(1),
    low: (((dist.low || 0) / total) * 100).toFixed(1),
  };
});

// Hallucination distribution percentages
const hallucinationPercentages = computed(() => {
  const dist = summary?.quality?.hallucination_distribution || {};
  const total = Object.values(dist).reduce((a, b) => a + b, 0);
  if (total === 0) return { high: 0, medium: 0, low: 0 };

  return {
    high: (((dist.high || 0) / total) * 100).toFixed(1),
    medium: (((dist.medium || 0) / total) * 100).toFixed(1),
    low: (((dist.low || 0) / total) * 100).toFixed(1),
  };
});

// Health status helper
const getHealthStatus = value => {
  if (value === null || value === undefined) return '🟡';
  if (value < 0.5) return '🟢';
  if (value < 2) return '🟡';
  return '🔴';
};

const getErrorHealthStatus = rate => {
  if (rate < 1) return '🟢';
  if (rate < 5) return '🟡';
  return '🔴';
};
</script>

<template>
  <div class="w-full h-full overflow-auto bg-slate-50">
    <header
      class="main-content__header bg-white border-b border-slate-200 px-6 py-4"
      role="banner"
    >
      <div class="flex items-center justify-between">
        <div>
          <h1 id="page-title" class="text-2xl font-bold text-slate-800">
            🚀 Saturn Analytics
          </h1>
          <p class="text-sm text-slate-500 mt-1">
            AI Asistan Kullanım ve Maliyet Takibi
          </p>
        </div>
        <div class="flex items-center gap-4">
          <select
            v-model="selectedPeriod"
            class="px-4 py-2 border border-slate-300 rounded-lg text-sm bg-white"
          >
            <option value="today">Bugün</option>
            <option value="this_week">Bu Hafta</option>
            <option value="this_month">Bu Ay</option>
            <option value="all">Tümü</option>
          </select>
        </div>
      </div>
    </header>

    <section class="p-6">
      <!-- Overview Cards -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
        <!-- Total Cost -->
        <div class="bg-white rounded-xl shadow-sm border border-slate-200 p-5">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm text-slate-500">Toplam Maliyet</p>
              <p class="text-2xl font-bold text-slate-800 mt-1">
                {{ formatCurrency(summary?.overview?.total_cost) }}
              </p>
            </div>
            <div
              class="w-12 h-12 bg-green-100 rounded-full flex items-center justify-center"
            >
              <span class="text-2xl">💰</span>
            </div>
          </div>
        </div>

        <!-- Total Requests -->
        <div class="bg-white rounded-xl shadow-sm border border-slate-200 p-5">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm text-slate-500">Toplam İstek</p>
              <p class="text-2xl font-bold text-slate-800 mt-1">
                {{ formatNumber(summary?.overview?.total_requests) }}
              </p>
            </div>
            <div
              class="w-12 h-12 bg-blue-100 rounded-full flex items-center justify-center"
            >
              <span class="text-2xl">📊</span>
            </div>
          </div>
        </div>

        <!-- Total Tokens -->
        <div class="bg-white rounded-xl shadow-sm border border-slate-200 p-5">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm text-slate-500">Toplam Token</p>
              <p class="text-2xl font-bold text-slate-800 mt-1">
                {{ formatNumber(summary?.overview?.total_tokens) }}
              </p>
            </div>
            <div
              class="w-12 h-12 bg-purple-100 rounded-full flex items-center justify-center"
            >
              <span class="text-2xl">🔢</span>
            </div>
          </div>
        </div>

        <!-- Avg Response Time -->
        <div class="bg-white rounded-xl shadow-sm border border-slate-200 p-5">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm text-slate-500">Ort. Yanıt Süresi</p>
              <p class="text-2xl font-bold text-slate-800 mt-1">
                {{ summary?.overview?.avg_response_time || 0 }}s
              </p>
            </div>
            <div
              class="w-12 h-12 bg-yellow-100 rounded-full flex items-center justify-center"
            >
              <span class="text-2xl">⏱️</span>
            </div>
          </div>
        </div>
      </div>

      <!-- API Type Breakdown -->
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
        <!-- Chat API Stats -->
        <div class="bg-white rounded-xl shadow-sm border border-slate-200 p-6">
          <h3
            class="text-lg font-semibold text-slate-800 mb-4 flex items-center gap-2"
          >
            <span>💬</span> Chat API (GPT)
          </h3>
          <div class="grid grid-cols-2 gap-4">
            <div class="bg-slate-50 rounded-lg p-4">
              <p class="text-sm text-slate-500">İstek Sayısı</p>
              <p class="text-xl font-bold text-slate-800">
                {{ formatNumber(summary?.chat?.requests) }}
              </p>
            </div>
            <div class="bg-slate-50 rounded-lg p-4">
              <p class="text-sm text-slate-500">Input Token</p>
              <p class="text-xl font-bold text-slate-800">
                {{ formatNumber(summary?.chat?.input_tokens) }}
              </p>
            </div>
            <div class="bg-slate-50 rounded-lg p-4">
              <p class="text-sm text-slate-500">Output Token</p>
              <p class="text-xl font-bold text-slate-800">
                {{ formatNumber(summary?.chat?.output_tokens) }}
              </p>
            </div>
            <div class="bg-green-50 rounded-lg p-4">
              <p class="text-sm text-green-600">Maliyet</p>
              <p class="text-xl font-bold text-green-700">
                {{ formatCurrency(summary?.chat?.cost) }}
              </p>
            </div>
          </div>
        </div>

        <!-- Embedding API Stats -->
        <div class="bg-white rounded-xl shadow-sm border border-slate-200 p-6">
          <h3
            class="text-lg font-semibold text-slate-800 mb-4 flex items-center gap-2"
          >
            <span>🔍</span> Embedding API
          </h3>
          <div class="grid grid-cols-2 gap-4">
            <div class="bg-slate-50 rounded-lg p-4">
              <p class="text-sm text-slate-500">İstek Sayısı</p>
              <p class="text-xl font-bold text-slate-800">
                {{ formatNumber(summary?.embedding?.requests) }}
              </p>
            </div>
            <div class="bg-slate-50 rounded-lg p-4">
              <p class="text-sm text-slate-500">Token</p>
              <p class="text-xl font-bold text-slate-800">
                {{ formatNumber(summary?.embedding?.tokens) }}
              </p>
            </div>
            <div class="bg-blue-50 rounded-lg p-4">
              <p class="text-sm text-blue-600">Cache Hit Oranı</p>
              <p class="text-xl font-bold text-blue-700">
                {{ formatPercent(summary?.embedding?.cache_hit_rate) }}
              </p>
            </div>
            <div class="bg-green-50 rounded-lg p-4">
              <p class="text-sm text-green-600">Maliyet</p>
              <p class="text-xl font-bold text-green-700">
                {{ formatCurrency(summary?.embedding?.cost) }}
              </p>
            </div>
          </div>
        </div>
      </div>

      <!-- Daily Trend Chart -->
      <div
        class="bg-white rounded-xl shadow-sm border border-slate-200 p-6 mb-6"
      >
        <h3
          class="text-lg font-semibold text-slate-800 mb-4 flex items-center gap-2"
        >
          <span>📈</span> Günlük Maliyet Trendi (Son 30 Gün)
        </h3>
        <div class="h-64">
          <BarChart
            v-if="chartData.labels.length > 0"
            :collection="chartData"
            class="w-full h-full"
          />
          <div
            v-else
            class="flex items-center justify-center h-full text-slate-400"
          >
            Henüz veri yok
          </div>
        </div>
      </div>

      <!-- Account Usage & Model Usage -->
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
        <!-- Account Usage -->
        <div class="bg-white rounded-xl shadow-sm border border-slate-200 p-6">
          <h3
            class="text-lg font-semibold text-slate-800 mb-4 flex items-center gap-2"
          >
            <span>👥</span> Hesap Bazlı Kullanım
          </h3>
          <div class="overflow-x-auto">
            <table class="w-full text-sm">
              <thead>
                <tr class="border-b border-slate-200">
                  <th class="text-left py-2 text-slate-500 font-medium">
                    Hesap
                  </th>
                  <th class="text-right py-2 text-slate-500 font-medium">
                    İstek
                  </th>
                  <th class="text-right py-2 text-slate-500 font-medium">
                    Token
                  </th>
                  <th class="text-right py-2 text-slate-500 font-medium">
                    Maliyet
                  </th>
                  <th class="text-right py-2 text-slate-500 font-medium">
                    Cache
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="account in accountUsage"
                  :key="account.account_id"
                  class="border-b border-slate-100 hover:bg-slate-50"
                >
                  <td class="py-3 font-medium text-slate-800">
                    {{ account.account_name }}
                  </td>
                  <td class="py-3 text-right text-slate-600">
                    {{ formatNumber(account.request_count) }}
                  </td>
                  <td class="py-3 text-right text-slate-600">
                    {{ formatNumber(account.total_tokens) }}
                  </td>
                  <td class="py-3 text-right font-medium text-green-600">
                    {{ formatCurrency(account.total_cost) }}
                  </td>
                  <td class="py-3 text-right text-slate-600">
                    {{ formatPercent(account.cache_hit_rate) }}
                  </td>
                </tr>
                <tr v-if="!accountUsage || accountUsage.length === 0">
                  <td colspan="5" class="py-6 text-center text-slate-400">
                    Henüz veri yok
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <!-- Model Usage -->
        <div class="bg-white rounded-xl shadow-sm border border-slate-200 p-6">
          <h3
            class="text-lg font-semibold text-slate-800 mb-4 flex items-center gap-2"
          >
            <span>🤖</span> Model Bazlı Kullanım
          </h3>
          <div class="overflow-x-auto">
            <table class="w-full text-sm">
              <thead>
                <tr class="border-b border-slate-200">
                  <th class="text-left py-2 text-slate-500 font-medium">
                    Model
                  </th>
                  <th class="text-right py-2 text-slate-500 font-medium">
                    İstek
                  </th>
                  <th class="text-right py-2 text-slate-500 font-medium">
                    Input
                  </th>
                  <th class="text-right py-2 text-slate-500 font-medium">
                    Output
                  </th>
                  <th class="text-right py-2 text-slate-500 font-medium">
                    Maliyet
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="model in modelUsage"
                  :key="model.model"
                  class="border-b border-slate-100 hover:bg-slate-50"
                >
                  <td class="py-3 font-medium text-slate-800">
                    {{ model.model }}
                  </td>
                  <td class="py-3 text-right text-slate-600">
                    {{ formatNumber(model.request_count) }}
                  </td>
                  <td class="py-3 text-right text-slate-600">
                    {{ formatNumber(model.input_tokens) }}
                  </td>
                  <td class="py-3 text-right text-slate-600">
                    {{ formatNumber(model.output_tokens) }}
                  </td>
                  <td class="py-3 text-right font-medium text-green-600">
                    {{ formatCurrency(model.cost) }}
                  </td>
                </tr>
                <tr v-if="!modelUsage || modelUsage.length === 0">
                  <td colspan="5" class="py-6 text-center text-slate-400">
                    Henüz veri yok
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <!-- Quality & System Health -->
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
        <!-- Quality Metrics -->
        <div class="bg-white rounded-xl shadow-sm border border-slate-200 p-6">
          <h3
            class="text-lg font-semibold text-slate-800 mb-4 flex items-center gap-2"
          >
            <span>✨</span> Kalite Metrikleri
          </h3>

          <div class="space-y-4">
            <!-- Confidence Distribution -->
            <div>
              <p class="text-sm text-slate-500 mb-2">Güven Dağılımı</p>
              <div class="flex items-center gap-2">
                <div
                  class="flex-1 bg-slate-100 rounded-full h-4 overflow-hidden"
                >
                  <div
                    class="h-full bg-green-500 float-left"
                    :style="{ width: confidencePercentages.high + '%' }"
                  />
                  <div
                    class="h-full bg-yellow-500 float-left"
                    :style="{ width: confidencePercentages.medium + '%' }"
                  />
                  <div
                    class="h-full bg-red-500 float-left"
                    :style="{ width: confidencePercentages.low + '%' }"
                  />
                </div>
              </div>
              <div class="flex justify-between text-xs text-slate-500 mt-1">
                <span>🟢 Yüksek: {{ confidencePercentages.high }}%</span>
                <span>🟡 Orta: {{ confidencePercentages.medium }}%</span>
                <span>🔴 Düşük: {{ confidencePercentages.low }}%</span>
              </div>
            </div>

            <!-- Hallucination Risk -->
            <div>
              <p class="text-sm text-slate-500 mb-2">
                Halüsinasyon Risk Dağılımı
              </p>
              <div class="flex items-center gap-2">
                <div
                  class="flex-1 bg-slate-100 rounded-full h-4 overflow-hidden"
                >
                  <div
                    class="h-full bg-green-500 float-left"
                    :style="{ width: hallucinationPercentages.low + '%' }"
                  />
                  <div
                    class="h-full bg-yellow-500 float-left"
                    :style="{ width: hallucinationPercentages.medium + '%' }"
                  />
                  <div
                    class="h-full bg-red-500 float-left"
                    :style="{ width: hallucinationPercentages.high + '%' }"
                  />
                </div>
              </div>
              <div class="flex justify-between text-xs text-slate-500 mt-1">
                <span>🟢 Düşük: {{ hallucinationPercentages.low }}%</span>
                <span>🟡 Orta: {{ hallucinationPercentages.medium }}%</span>
                <span>🔴 Yüksek: {{ hallucinationPercentages.high }}%</span>
              </div>
            </div>

            <!-- Other Quality Stats -->
            <div class="grid grid-cols-2 gap-3 mt-4">
              <div class="bg-slate-50 rounded-lg p-3">
                <p class="text-xs text-slate-500">"Bilmiyorum" Oranı</p>
                <p class="text-lg font-bold text-slate-800">
                  {{ formatPercent(summary?.quality?.no_info_rate) }}
                </p>
              </div>
              <div class="bg-slate-50 rounded-lg p-3">
                <p class="text-xs text-slate-500">Hata Oranı</p>
                <p class="text-lg font-bold text-slate-800">
                  {{ formatPercent(summary?.quality?.error_rate) }}
                </p>
              </div>
            </div>
          </div>
        </div>

        <!-- System Health -->
        <div class="bg-white rounded-xl shadow-sm border border-slate-200 p-6">
          <h3
            class="text-lg font-semibold text-slate-800 mb-4 flex items-center gap-2"
          >
            <span>🏥</span> Sistem Sağlığı (Son 24 Saat)
          </h3>

          <div class="space-y-4">
            <!-- Response Times -->
            <div>
              <p class="text-sm text-slate-500 mb-2">Yanıt Süreleri</p>
              <div class="grid grid-cols-2 gap-3">
                <div
                  class="bg-slate-50 rounded-lg p-3 flex items-center justify-between"
                >
                  <div>
                    <p class="text-xs text-slate-500">Chat API</p>
                    <p class="text-lg font-bold text-slate-800">
                      {{ systemHealth?.response_times?.chat_avg || 0 }}s
                    </p>
                  </div>
                  <span class="text-xl">{{
                    getHealthStatus(systemHealth?.response_times?.chat_avg)
                  }}</span>
                </div>
                <div
                  class="bg-slate-50 rounded-lg p-3 flex items-center justify-between"
                >
                  <div>
                    <p class="text-xs text-slate-500">Embedding</p>
                    <p class="text-lg font-bold text-slate-800">
                      {{ systemHealth?.response_times?.embedding_avg || 0 }}s
                    </p>
                  </div>
                  <span class="text-xl">{{
                    getHealthStatus(systemHealth?.response_times?.embedding_avg)
                  }}</span>
                </div>
              </div>
            </div>

            <!-- Errors -->
            <div>
              <p class="text-sm text-slate-500 mb-2">Hatalar</p>
              <div
                class="bg-slate-50 rounded-lg p-3 flex items-center justify-between"
              >
                <div>
                  <p class="text-xs text-slate-500">Toplam Hata</p>
                  <p class="text-lg font-bold text-slate-800">
                    {{ systemHealth?.errors?.total || 0 }}
                    <span class="text-sm font-normal text-slate-500">
                      ({{ formatPercent(systemHealth?.errors?.rate) }})
                    </span>
                  </p>
                </div>
                <span class="text-xl">{{
                  getErrorHealthStatus(systemHealth?.errors?.rate)
                }}</span>
              </div>
            </div>

            <!-- Hallucination Stats -->
            <div>
              <p class="text-sm text-slate-500 mb-2">Halüsinasyon (24 saat)</p>
              <div class="grid grid-cols-3 gap-2">
                <div class="bg-green-50 rounded-lg p-2 text-center">
                  <p class="text-xs text-green-600">Düşük</p>
                  <p class="text-lg font-bold text-green-700">
                    {{ systemHealth?.hallucination?.low || 0 }}
                  </p>
                </div>
                <div class="bg-yellow-50 rounded-lg p-2 text-center">
                  <p class="text-xs text-yellow-600">Orta</p>
                  <p class="text-lg font-bold text-yellow-700">
                    {{ systemHealth?.hallucination?.medium || 0 }}
                  </p>
                </div>
                <div class="bg-red-50 rounded-lg p-2 text-center">
                  <p class="text-xs text-red-600">Yüksek</p>
                  <p class="text-lg font-bold text-red-700">
                    {{ systemHealth?.hallucination?.high || 0 }}
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Assistant Performance -->
      <div
        class="bg-white rounded-xl shadow-sm border border-slate-200 p-6 mb-6"
      >
        <h3
          class="text-lg font-semibold text-slate-800 mb-4 flex items-center gap-2"
        >
          <span>🤖</span> Asistan Performansı
        </h3>
        <div class="overflow-x-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-slate-200">
                <th class="text-left py-2 text-slate-500 font-medium">
                  Asistan
                </th>
                <th class="text-left py-2 text-slate-500 font-medium">Hesap</th>
                <th class="text-right py-2 text-slate-500 font-medium">
                  Mesaj
                </th>
                <th class="text-right py-2 text-slate-500 font-medium">
                  Maliyet
                </th>
                <th class="text-right py-2 text-slate-500 font-medium">
                  Ort. Süre
                </th>
                <th class="text-right py-2 text-slate-500 font-medium">
                  "Bilmiyorum"
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="assistant in assistantPerformance"
                :key="assistant.assistant_id"
                class="border-b border-slate-100 hover:bg-slate-50"
              >
                <td class="py-3 font-medium text-slate-800">
                  {{ assistant.assistant_name }}
                </td>
                <td class="py-3 text-slate-600">
                  {{ assistant.account_name }}
                </td>
                <td class="py-3 text-right text-slate-600">
                  {{ formatNumber(assistant.message_count) }}
                </td>
                <td class="py-3 text-right font-medium text-green-600">
                  {{ formatCurrency(assistant.total_cost) }}
                </td>
                <td class="py-3 text-right text-slate-600">
                  {{ assistant.avg_response_time || 0 }}s
                </td>
                <td class="py-3 text-right">
                  <span
                    class="px-2 py-1 rounded text-xs font-medium"
                    :class="[
                      assistant.no_info_rate > 15
                        ? 'bg-red-100 text-red-700'
                        : assistant.no_info_rate > 5
                          ? 'bg-yellow-100 text-yellow-700'
                          : 'bg-green-100 text-green-700',
                    ]"
                  >
                    {{ assistant.no_info_rate }}%
                  </span>
                </td>
              </tr>
              <tr
                v-if="
                  !assistantPerformance || assistantPerformance.length === 0
                "
              >
                <td colspan="6" class="py-6 text-center text-slate-400">
                  Henüz veri yok
                </td>
              </tr>
            </tbody>
          </table>
        </div>
        <p class="text-xs text-slate-400 mt-3">
          💡 "Bilmiyorum" oranı yüksek olan asistanlara daha fazla SSS/döküman
          eklenmeli.
        </p>
      </div>

      <!-- Resource Stats -->
      <div class="bg-white rounded-xl shadow-sm border border-slate-200 p-6">
        <h3
          class="text-lg font-semibold text-slate-800 mb-4 flex items-center gap-2"
        >
          <span>📦</span> Kaynak Durumu
        </h3>
        <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
          <div class="bg-slate-50 rounded-lg p-4 text-center">
            <p class="text-2xl font-bold text-slate-800">
              {{ stats?.totalAssistants || 0 }}
            </p>
            <p class="text-xs text-slate-500 mt-1">Toplam Asistan</p>
          </div>
          <div class="bg-slate-50 rounded-lg p-4 text-center">
            <p class="text-2xl font-bold text-green-600">
              {{ stats?.activeAssistants || 0 }}
            </p>
            <p class="text-xs text-slate-500 mt-1">Aktif Asistan</p>
          </div>
          <div class="bg-slate-50 rounded-lg p-4 text-center">
            <p class="text-2xl font-bold text-slate-800">
              {{ stats?.totalFaqs || 0 }}
            </p>
            <p class="text-xs text-slate-500 mt-1">Toplam SSS</p>
          </div>
          <div class="bg-slate-50 rounded-lg p-4 text-center">
            <p class="text-2xl font-bold text-blue-600">
              {{ stats?.faqsWithEmbedding || 0 }}
            </p>
            <p class="text-xs text-slate-500 mt-1">Embedding'li SSS</p>
          </div>
          <div class="bg-slate-50 rounded-lg p-4 text-center">
            <p class="text-2xl font-bold text-slate-800">
              {{ stats?.totalDocuments || 0 }}
            </p>
            <p class="text-xs text-slate-500 mt-1">Toplam Döküman</p>
          </div>
          <div class="bg-slate-50 rounded-lg p-4 text-center">
            <p class="text-2xl font-bold text-purple-600">
              {{ stats?.chunksWithEmbedding || 0 }}
            </p>
            <p class="text-xs text-slate-500 mt-1">Embedding'li Chunk</p>
          </div>
        </div>
      </div>
    </section>
  </div>
</template>

<style scoped>
.main-content__header {
  position: sticky;
  top: 0;
  z-index: 10;
}
</style>

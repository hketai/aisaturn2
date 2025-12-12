<script setup>
import { computed, onMounted, ref } from 'vue';
import { OVERVIEW_METRICS } from '../constants';
import { useToggle } from '@vueuse/core';

import MetricCard from './overview/MetricCard.vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useLiveRefresh } from 'dashboard/composables/useLiveRefresh';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { useI18n } from 'vue-i18n';

const { t } = useI18n();

const uiFlags = useMapGetter('getOverviewUIFlags');
const agentStatus = useMapGetter('agents/getAgentStatus');
const accountConversationMetric = useMapGetter('getAccountConversationMetric');
const store = useStore();

const accounti18nKey = 'OVERVIEW_REPORTS.ACCOUNT_CONVERSATIONS';
const teams = useMapGetter('teams/getTeams');

const teamMenuList = computed(() => {
  return [
    { label: t('OVERVIEW_REPORTS.TEAM_CONVERSATIONS.ALL_TEAMS'), value: null },
    ...teams.value.map(team => ({ label: team.name, value: team.id })),
  ];
});

const agentStatusMetrics = computed(() => {
  let metric = {};
  Object.keys(agentStatus.value).forEach(key => {
    const metricName = t(
      `OVERVIEW_REPORTS.AGENT_STATUS.${OVERVIEW_METRICS[key]}`
    );
    metric[metricName] = agentStatus.value[key];
  });
  return metric;
});

const conversationMetrics = computed(() => {
  let metric = {};
  Object.keys(accountConversationMetric.value).forEach(key => {
    const metricName = t(`${accounti18nKey}.${OVERVIEW_METRICS[key]}`);
    metric[metricName] = accountConversationMetric.value[key];
  });
  return metric;
});

const selectedTeam = ref(null);
const selectedTeamLabel = computed(() => {
  const team =
    teamMenuList.value.find(
      menuItem => menuItem.value === selectedTeam.value
    ) || {};
  return team.label;
});

const fetchData = () => {
  const params = {};
  if (selectedTeam.value) {
    params.team_id = selectedTeam.value;
  }
  store.dispatch('fetchAccountConversationMetric', params);
};

const { startRefetching } = useLiveRefresh(fetchData);
const [showDropdown, toggleDropdown] = useToggle();

const handleAction = ({ value }) => {
  toggleDropdown(false);
  selectedTeam.value = value;
  fetchData();
};

onMounted(() => {
  fetchData();
  startRefetching();
});

// Metric icons mapping
const metricIcons = {
  open: 'i-lucide-message-circle',
  unattended: 'i-lucide-clock',
  unassigned: 'i-lucide-user-x',
  pending: 'i-lucide-pause-circle',
  online: 'i-lucide-circle-dot',
  busy: 'i-lucide-loader',
  offline: 'i-lucide-circle-off',
};

const metricColors = {
  open: 'bg-n-blue-3 text-n-blue-11',
  unattended: 'bg-n-amber-3 text-n-amber-11',
  unassigned: 'bg-n-ruby-3 text-n-ruby-11',
  pending: 'bg-n-violet-3 text-n-violet-11',
  online: 'bg-n-teal-3 text-n-teal-11',
  busy: 'bg-n-amber-3 text-n-amber-11',
  offline: 'bg-n-slate-3 text-n-slate-11',
};

const getMetricStyle = (index, isAgent = false) => {
  const keys = isAgent
    ? ['online', 'busy', 'offline']
    : ['open', 'unattended', 'unassigned', 'pending'];
  return {
    icon: metricIcons[keys[index]] || 'i-lucide-activity',
    color: metricColors[keys[index]] || 'bg-n-slate-3 text-n-slate-11',
  };
};
</script>

<template>
  <div class="grid grid-cols-1 lg:grid-cols-5 gap-6">
    <!-- Conversation Metrics Card -->
    <div class="lg:col-span-3">
      <MetricCard
        :header="t(`${accounti18nKey}.HEADER`)"
        :is-loading="uiFlags.isFetchingAccountConversationMetric"
        :loading-message="t(`${accounti18nKey}.LOADING_MESSAGE`)"
        icon="i-lucide-message-square"
      >
        <template v-if="teams.length" #control>
          <div
            v-on-clickaway="() => toggleDropdown(false)"
            class="relative flex items-center"
          >
            <Button
              sm
              slate
              faded
              :label="selectedTeamLabel"
              icon="i-lucide-chevron-down"
              class="capitalize"
              @click="toggleDropdown()"
            />
            <DropdownMenu
              v-if="showDropdown"
              :menu-items="teamMenuList"
              class="mt-1 ltr:right-0 rtl:left-0 top-full min-w-[12rem]"
              label-class="capitalize"
              @action="handleAction($event)"
            />
          </div>
        </template>

        <!-- Metric Items -->
        <div
          v-for="(metric, name, index) in conversationMetrics"
          :key="index"
          class="flex items-center gap-4 p-4 bg-n-slate-2 rounded-xl min-w-[140px] flex-1"
        >
          <div
            class="w-10 h-10 rounded-lg flex items-center justify-center"
            :class="getMetricStyle(index).color"
          >
            <i :class="getMetricStyle(index).icon" class="text-lg" />
          </div>
          <div class="flex flex-col">
            <span class="text-2xl font-semibold text-n-slate-12">
              {{ metric }}
            </span>
            <span class="text-xs text-n-slate-11">
              {{ name }}
            </span>
          </div>
        </div>
      </MetricCard>
    </div>

    <!-- Agent Status Card -->
    <div class="lg:col-span-2">
      <MetricCard
        :header="t('OVERVIEW_REPORTS.AGENT_STATUS.HEADER')"
        icon="i-lucide-users"
      >
        <!-- Agent Status Items -->
        <div
          v-for="(metric, name, index) in agentStatusMetrics"
          :key="index"
          class="flex items-center gap-4 p-4 bg-n-slate-2 rounded-xl min-w-[120px] flex-1"
        >
          <div
            class="w-10 h-10 rounded-lg flex items-center justify-center"
            :class="getMetricStyle(index, true).color"
          >
            <i :class="getMetricStyle(index, true).icon" class="text-lg" />
          </div>
          <div class="flex flex-col">
            <span class="text-2xl font-semibold text-n-slate-12">
              {{ metric }}
            </span>
            <span class="text-xs text-n-slate-11">
              {{ name }}
            </span>
          </div>
        </div>
      </MetricCard>
    </div>
  </div>
</template>

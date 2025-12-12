<script setup>
import { onMounted } from 'vue';

import MetricCard from './overview/MetricCard.vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useLiveRefresh } from 'dashboard/composables/useLiveRefresh';
import TeamTable from './overview/TeamTable.vue';

const store = useStore();

const uiFlags = useMapGetter('getOverviewUIFlags');
const teamConversationMetric = useMapGetter('getTeamConversationMetric');
const teams = useMapGetter('teams/getTeams');

const fetchData = () => store.dispatch('fetchTeamConversationMetric');

const { startRefetching } = useLiveRefresh(fetchData);

onMounted(() => {
  store.dispatch('teams/get');
  fetchData();
  startRefetching();
});
</script>

<template>
  <MetricCard
    :header="$t('OVERVIEW_REPORTS.TEAM_CONVERSATIONS.HEADER')"
    icon="i-lucide-users"
  >
    <div class="w-full">
      <TeamTable
        :teams="teams"
        :team-metrics="teamConversationMetric"
        :is-loading="uiFlags.isFetchingTeamConversationMetric"
      />
    </div>
  </MetricCard>
</template>

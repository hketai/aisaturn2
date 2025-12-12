<script setup>
import { useI18n } from 'vue-i18n';
import ConversationHeatmapContainer from './components/heatmaps/ConversationHeatmapContainer.vue';
import ResolutionHeatmapContainer from './components/heatmaps/ResolutionHeatmapContainer.vue';
import AgentLiveReportContainer from './components/AgentLiveReportContainer.vue';
import TeamLiveReportContainer from './components/TeamLiveReportContainer.vue';
import StatsLiveReportsContainer from './components/StatsLiveReportsContainer.vue';

const { t } = useI18n();
</script>

<template>
  <div class="py-8">
    <!-- Header -->
    <div class="mb-8">
      <h1 class="text-2xl font-semibold text-n-slate-12">
        {{ t('OVERVIEW_REPORTS.HEADER') }}
      </h1>
    </div>

    <!-- Stats Cards -->
    <StatsLiveReportsContainer />

    <!-- Heatmaps Grid -->
    <div class="grid grid-cols-1 xl:grid-cols-2 gap-6 mt-6">
      <ConversationHeatmapContainer />
      <ResolutionHeatmapContainer />
    </div>

    <!-- Tables Grid -->
    <div class="grid grid-cols-1 xl:grid-cols-2 gap-6 mt-6">
      <AgentLiveReportContainer />
      <TeamLiveReportContainer />
    </div>
  </div>
</template>

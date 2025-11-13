<script setup>
import { computed } from 'vue';
import { usePolicy } from 'dashboard/composables/usePolicy';
import Button from 'dashboard/components-next/button/Button.vue';
import BackButton from 'dashboard/components/widgets/BackButton.vue';
import PaginationFooter from 'dashboard/components-next/pagination/PaginationFooter.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Policy from 'dashboard/components/policy.vue';

const props = defineProps({
  pageNumber: {
    type: Number,
    default: 1,
  },
  totalRecords: {
    type: Number,
    default: 100,
  },
  recordsPerPage: {
    type: Number,
    default: 25,
  },
  pageTitle: {
    type: String,
    default: '',
  },
  returnPath: {
    type: [String, Object],
    default: '',
  },
  actionPermissions: {
    type: Array,
    default: () => [],
  },
  actionButtonText: {
    type: String,
    default: '',
  },
  featureFlagKey: {
    type: String,
    default: '',
  },
  isLoading: {
    type: Boolean,
    default: false,
  },
  showInfoButton: {
    type: Boolean,
    default: true,
  },
  hasNoData: {
    type: Boolean,
    default: false,
  },
  enablePagination: {
    type: Boolean,
    default: true,
  },
});

const emit = defineEmits(['action', 'pageChange']);
const { shouldShowPaywall } = usePolicy();

const displayPaywall = computed(() => {
  return shouldShowPaywall(props.featureFlagKey);
});

const triggerAction = () => {
  emit('action');
};

const onPageChange = event => {
  emit('pageChange', event);
};
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-hidden bg-n-background">
    <header class="sticky top-0 z-10 px-6">
      <div class="w-full max-w-[60rem] mx-auto">
        <div
          class="flex items-start lg:items-center justify-between w-full py-6 lg:py-0 lg:h-20 gap-4 lg:gap-2 flex-col lg:flex-row"
        >
          <div class="flex gap-4 items-center">
            <BackButton v-if="returnPath" :to="returnPath" />
            <slot name="pageTitle">
              <div class="flex flex-col">
                <span class="text-xl font-medium text-n-slate-12">
                  {{ pageTitle }}
                </span>
                <span
                  v-if="totalRecords > 0"
                  class="text-sm text-n-slate-11 mt-0.5"
                >
                  <slot name="subtitle" />
                </span>
              </div>
            </slot>
            <div
              v-if="!hasNoData && showInfoButton"
              class="flex items-center gap-2"
            >
              <div class="w-0.5 h-4 rounded-2xl bg-n-weak" />
              <slot name="infoSection" />
            </div>
          </div>

          <div
            v-if="!displayPaywall && actionButtonText"
            v-on-clickaway="() => emit('close')"
            class="relative group/action-button"
          >
            <Policy :permissions="actionPermissions">
              <Button
                :label="actionButtonText"
                icon="i-lucide-plus"
                size="sm"
                class="group-hover/action-button:brightness-110"
                @click="triggerAction"
              />
            </Policy>
            <slot name="headerAction" />
          </div>
        </div>
      </div>
    </header>
    <main class="flex-1 px-6 overflow-y-auto">
      <div class="w-full max-w-[60rem] h-full mx-auto py-4">
        <slot v-if="!displayPaywall" name="topControls" />
        <div
          v-if="isLoading"
          class="flex items-center justify-center py-10 text-n-slate-11"
        >
          <Spinner />
        </div>
        <div v-else-if="displayPaywall">
          <slot name="paywallSection" />
        </div>
        <div v-else-if="hasNoData">
          <slot name="emptyStateSection" />
        </div>
        <slot v-else name="contentArea" />
        <slot />
      </div>
    </main>
    <footer v-if="enablePagination" class="sticky bottom-0 z-10 px-4 pb-4">
      <PaginationFooter
        :current-page="pageNumber"
        :total-items="totalRecords"
        :items-per-page="recordsPerPage"
        @update:current-page="onPageChange"
      />
    </footer>
  </section>
</template>

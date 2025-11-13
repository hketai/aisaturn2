<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import SaturnResponseCard from 'dashboard/components-next/saturn/response/SaturnResponseCard.vue';
import saturnResponseAPI from 'dashboard/api/saturn/response';

const props = defineProps({
  document: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['close']);
const { t } = useI18n();
const dialogRef = ref(null);
const responses = ref([]);
const isFetching = ref(false);

const handleClose = () => {
  emit('close');
};

const fetchRelatedResponses = async () => {
  isFetching.value = true;
  try {
    const response = await saturnResponseAPI.get({
      assistantId: props.document.assistant?.id,
    });
    const allResponses = Array.isArray(response.data) ? response.data : [];
    responses.value = allResponses.filter(
      r => r.document?.id === props.document.id
    );
  } catch (error) {
    console.error('Error fetching related responses:', error);
    responses.value = [];
  } finally {
    isFetching.value = false;
  }
};

onMounted(() => {
  fetchRelatedResponses();
});

defineExpose({ dialogRef });
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="edit"
    :title="$t('SATURN.DOCUMENTS.RELATED_RESPONSES.TITLE')"
    :description="$t('SATURN.DOCUMENTS.RELATED_RESPONSES.DESCRIPTION')"
    :show-cancel-button="false"
    :show-confirm-button="false"
    overflow-y-auto
    width="3xl"
    @close="handleClose"
  >
    <div
      v-if="isFetching"
      class="flex items-center justify-center py-10 text-n-slate-11"
    >
      <Spinner />
    </div>
    <div v-else class="flex flex-col gap-3 min-h-48">
      <SaturnResponseCard
        v-for="response in responses"
        :id="response.id"
        :key="response.id"
        :question="response.question"
        :answer="response.answer"
        :status="response.status"
        :assistant="response.assistant"
        :created-at="response.created_at"
      />
      <div v-if="!responses.length" class="text-center py-8 text-n-slate-11">
        {{ $t('SATURN.DOCUMENTS.RELATED_RESPONSES.EMPTY') }}
      </div>
    </div>
  </Dialog>
</template>

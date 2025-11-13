<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import SaturnMessageList from './SaturnMessageList.vue';
import saturnAssistantAPI from 'dashboard/api/saturn/assistant';

const props = defineProps({
  assistantId: {
    type: Number,
    required: true,
  },
});

const { t } = useI18n();
const conversationMessages = ref([]);
const userInput = ref('');
const isProcessing = ref(false);
const errorMessage = ref('');

const prepareMessageHistory = () => {
  // Convert sender to OpenAI role format
  // 'user' -> 'user', 'assistant' -> 'assistant', 'error' -> skip
  return conversationMessages.value
    .filter(msg => msg.sender !== 'error')
    .map(msg => ({
      role: msg.sender === 'assistant' ? 'assistant' : 'user',
      content: msg.content || '',
    }));
};

const clearConversation = () => {
  conversationMessages.value = [];
  userInput.value = '';
};

const processUserMessage = async () => {
  if (!userInput.value.trim() || isProcessing.value) return;

  const userMsg = {
    content: userInput.value,
    sender: 'user',
    timestamp: new Date().toISOString(),
  };
  conversationMessages.value.push(userMsg);
  const currentInput = userInput.value;
  userInput.value = '';

  try {
    isProcessing.value = true;
    errorMessage.value = '';
    const { data } = await saturnAssistantAPI.playground({
      assistantId: props.assistantId,
      messageContent: currentInput,
      messageHistory: prepareMessageHistory(),
    });

    if (data?.message) {
      conversationMessages.value.push({
        content: data.message,
        sender: 'assistant',
        timestamp: new Date().toISOString(),
      });
    } else {
      errorMessage.value = t('SATURN.TEST_INTERFACE.ERROR_NO_RESPONSE');
    }
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error('Error getting Saturn assistant response:', error);
    const errorText =
      error?.response?.data?.error ||
      error?.message ||
      t('SATURN.TEST_INTERFACE.ERROR_GENERIC');
    errorMessage.value = errorText;
    conversationMessages.value.push({
      content: errorText,
      sender: 'error',
      timestamp: new Date().toISOString(),
    });
  } finally {
    isProcessing.value = false;
  }
};
</script>

<template>
  <div
    class="flex flex-col h-full rounded-lg p-4 border border-n-slate-4 text-n-slate-11"
  >
    <div class="mb-4">
      <div class="flex justify-between items-center mb-1">
        <h3 class="text-lg font-medium">
          {{ t('SATURN.TEST_INTERFACE.HEADER') }}
        </h3>
        <Button
          variant="ghost"
          size="sm"
          icon="i-lucide-rotate-ccw"
          @click="clearConversation"
        />
      </div>
      <p class="text-sm text-n-slate-11">
        {{ t('SATURN.TEST_INTERFACE.DESCRIPTION') }}
      </p>
    </div>

    <SaturnMessageList
      :messages="conversationMessages"
      :is-loading="isProcessing"
    />

    <div
      class="flex items-center bg-n-solid-1 outline outline-n-container rounded-lg p-3"
    >
      <input
        v-model="userInput"
        class="flex-1 bg-transparent border-none focus:outline-none text-sm mb-0"
        :placeholder="t('SATURN.TEST_INTERFACE.MESSAGE_PLACEHOLDER')"
        @keyup.enter="processUserMessage"
      />
      <Button
        variant="ghost"
        size="sm"
        :disabled="!userInput.trim()"
        icon="i-lucide-send"
        @click="processUserMessage"
      />
    </div>

    <p class="text-xs text-n-slate-11 pt-2 text-center">
      {{ t('SATURN.TEST_INTERFACE.CREDIT_NOTE') }}
    </p>
  </div>
</template>

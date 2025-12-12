<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import router from '../../../../index';
import NextButton from 'dashboard/components-next/button/Button.vue';
import GreetingsEditor from 'shared/components/GreetingsEditor.vue';
import { WIDGET_BUILDER_EDITOR_MENU_OPTIONS } from 'dashboard/constants/editor';
import Editor from 'dashboard/components-next/Editor/Editor.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

export default {
  components: {
    GreetingsEditor,
    NextButton,
    Editor,
    Icon,
  },
  data() {
    return {
      inboxName: '',
      channelWebsiteUrl: '',
      channelWidgetColor: '#009CE0',
      channelWelcomeTitle: '',
      channelWelcomeTagline: '',
      greetingEnabled: false,
      greetingMessage: '',
      welcomeTaglineEditorMenuOptions: WIDGET_BUILDER_EDITOR_MENU_OPTIONS,
    };
  },
  computed: {
    ...mapGetters({
      uiFlags: 'inboxes/getUIFlags',
    }),
    textAreaChannels() {
      if (
        this.isATwilioChannel ||
        this.isATwitterInbox ||
        this.isAFacebookInbox
      )
        return true;
      return false;
    },
    isFormValid() {
      return this.inboxName?.trim() && this.channelWebsiteUrl?.trim();
    },
  },
  methods: {
    async createChannel() {
      try {
        const website = await this.$store.dispatch(
          'inboxes/createWebsiteChannel',
          {
            name: this.inboxName?.trim(),
            greeting_enabled: this.greetingEnabled,
            greeting_message: this.greetingMessage,
            channel: {
              type: 'web_widget',
              website_url: this.channelWebsiteUrl,
              widget_color: this.channelWidgetColor,
              welcome_title: this.channelWelcomeTitle,
              welcome_tagline: this.channelWelcomeTagline,
            },
          }
        );
        router.replace({
          name: 'settings_inboxes_add_agents',
          params: {
            page: 'new',
            inbox_id: website.id,
          },
        });
      } catch (error) {
        useAlert(
          error.message ||
            this.$t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.API.ERROR_MESSAGE')
        );
      }
    },
  },
};
</script>

<template>
  <div class="h-full w-full overflow-auto">
    <div class="max-w-2xl mx-auto p-8">
      <!-- Loading State -->
      <div
        v-if="uiFlags.isCreating"
        class="flex flex-col items-center justify-center py-20"
      >
        <div class="w-12 h-12 border-4 border-n-brand border-t-transparent rounded-full animate-spin mb-4" />
        <p class="text-n-slate-11">{{ $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.LOADING_MESSAGE') }}</p>
      </div>

      <!-- Form -->
      <form
        v-else
        class="space-y-6"
        @submit.prevent="createChannel"
      >
        <!-- Header Card -->
        <div class="flex items-center gap-4 p-5 bg-n-brand/10 rounded-2xl border border-n-brand/20">
          <div class="w-12 h-12 bg-n-brand rounded-xl flex items-center justify-center">
            <Icon icon="i-lucide-message-square" class="w-6 h-6 text-white" />
          </div>
          <div>
            <h1 class="text-lg font-semibold text-n-slate-12">
              Web Sitesi Kanalı
            </h1>
            <p class="text-sm text-n-slate-11">
              Web sitenize canlı sohbet widget'ı ekleyin
            </p>
          </div>
        </div>

        <!-- Basic Info Section -->
        <div class="bg-n-slate-2 rounded-2xl border border-n-slate-4 overflow-hidden">
          <div class="px-5 py-4 border-b border-n-slate-4">
            <h2 class="text-sm font-semibold text-n-slate-12 flex items-center gap-2">
              <Icon icon="i-lucide-info" class="w-4 h-4 text-n-slate-10" />
              Temel Bilgiler
            </h2>
          </div>
          <div class="p-5 space-y-5">
            <!-- Inbox Name -->
            <div>
              <label class="block text-sm font-medium text-n-slate-12 mb-2">
                {{ $t('INBOX_MGMT.ADD.WEBSITE_NAME.LABEL') }}
              </label>
              <input
                v-model="inboxName"
                type="text"
                class="w-full px-4 py-3 bg-n-slate-1 border border-n-slate-4 rounded-xl text-n-slate-12 placeholder-n-slate-10 focus:border-n-brand focus:ring-1 focus:ring-n-brand outline-none transition-colors"
                :placeholder="$t('INBOX_MGMT.ADD.WEBSITE_NAME.PLACEHOLDER')"
              />
            </div>

            <!-- Website URL -->
            <div>
              <label class="block text-sm font-medium text-n-slate-12 mb-2">
                {{ $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_DOMAIN.LABEL') }}
              </label>
              <input
                v-model="channelWebsiteUrl"
                type="text"
                class="w-full px-4 py-3 bg-n-slate-1 border border-n-slate-4 rounded-xl text-n-slate-12 placeholder-n-slate-10 focus:border-n-brand focus:ring-1 focus:ring-n-brand outline-none transition-colors"
                :placeholder="$t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_DOMAIN.PLACEHOLDER')"
              />
            </div>
          </div>
        </div>

        <!-- Widget Customization Section -->
        <div class="bg-n-slate-2 rounded-2xl border border-n-slate-4 overflow-hidden">
          <div class="px-5 py-4 border-b border-n-slate-4">
            <h2 class="text-sm font-semibold text-n-slate-12 flex items-center gap-2">
              <Icon icon="i-lucide-palette" class="w-4 h-4 text-n-slate-10" />
              Widget Görünümü
            </h2>
          </div>
          <div class="p-5 space-y-5">
            <!-- Widget Color -->
            <div>
              <label class="block text-sm font-medium text-n-slate-12 mb-2">
                {{ $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.WIDGET_COLOR.LABEL') }}
              </label>
              <woot-color-picker v-model="channelWidgetColor" />
            </div>

            <!-- Welcome Title -->
            <div>
              <label class="block text-sm font-medium text-n-slate-12 mb-2">
                {{ $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_WELCOME_TITLE.LABEL') }}
              </label>
              <input
                v-model="channelWelcomeTitle"
                type="text"
                class="w-full px-4 py-3 bg-n-slate-1 border border-n-slate-4 rounded-xl text-n-slate-12 placeholder-n-slate-10 focus:border-n-brand focus:ring-1 focus:ring-n-brand outline-none transition-colors"
                :placeholder="$t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_WELCOME_TITLE.PLACEHOLDER')"
              />
            </div>

            <!-- Welcome Tagline -->
            <div>
              <label class="block text-sm font-medium text-n-slate-12 mb-2">
                {{ $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_WELCOME_TAGLINE.LABEL') }}
              </label>
              <Editor
                v-model="channelWelcomeTagline"
                :placeholder="$t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_WELCOME_TAGLINE.PLACEHOLDER')"
                :max-length="255"
                :enabled-menu-options="welcomeTaglineEditorMenuOptions"
              />
            </div>
          </div>
        </div>

        <!-- Greeting Section -->
        <div class="bg-n-slate-2 rounded-2xl border border-n-slate-4 overflow-hidden">
          <div class="px-5 py-4 border-b border-n-slate-4">
            <h2 class="text-sm font-semibold text-n-slate-12 flex items-center gap-2">
              <Icon icon="i-lucide-hand-wave" class="w-4 h-4 text-n-slate-10" />
              Karşılama Mesajı
            </h2>
          </div>
          <div class="p-5 space-y-5">
            <!-- Greeting Toggle -->
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-n-slate-12">
                  {{ $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_GREETING_TOGGLE.LABEL') }}
                </p>
                <p class="text-xs text-n-slate-10 mt-0.5">
                  {{ $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_GREETING_TOGGLE.HELP_TEXT') }}
                </p>
              </div>
              <label class="relative inline-flex items-center cursor-pointer">
                <input
                  v-model="greetingEnabled"
                  type="checkbox"
                  class="sr-only peer"
                />
                <div class="w-11 h-6 bg-n-slate-4 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-n-brand" />
              </label>
            </div>

            <!-- Greeting Message -->
            <div v-if="greetingEnabled">
              <GreetingsEditor
                v-model="greetingMessage"
                class="w-full"
                :label="$t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_GREETING_MESSAGE.LABEL')"
                :placeholder="$t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_GREETING_MESSAGE.PLACEHOLDER')"
                :richtext="!textAreaChannels"
              />
            </div>
          </div>
        </div>

        <!-- Submit Button -->
        <div class="flex justify-end pt-4">
          <button
            type="submit"
            :disabled="!isFormValid || uiFlags.isCreating"
            class="flex items-center gap-2 px-6 py-3 bg-n-brand text-white font-medium rounded-xl hover:bg-n-brand/90 disabled:opacity-50 disabled:cursor-not-allowed transition-all"
          >
            <Icon icon="i-lucide-plus" class="w-5 h-5" />
            {{ $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.SUBMIT_BUTTON') }}
          </button>
        </div>
      </form>
    </div>
  </div>
</template>

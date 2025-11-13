<script setup>
import { h, computed, onMounted } from 'vue';
import { provideSidebarContext } from './provider';
import { useAccount } from 'dashboard/composables/useAccount';
import { useKbd } from 'dashboard/composables/utils/useKbd';
import { useMapGetter } from 'dashboard/composables/store';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useStorage } from '@vueuse/core';
import { useSidebarKeyboardShortcuts } from './useSidebarKeyboardShortcuts';
import { vOnClickOutside } from '@vueuse/components';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

import Button from 'dashboard/components-next/button/Button.vue';
import SidebarGroup from './SidebarGroup.vue';
import SidebarProfileMenu from './SidebarProfileMenu.vue';
import ChannelLeaf from './ChannelLeaf.vue';
import SidebarAccountSwitcher from './SidebarAccountSwitcher.vue';
import Logo from 'next/icon/Logo.vue';
import ComposeConversation from 'dashboard/components-next/NewConversation/ComposeConversation.vue';
import SaturnIcon from 'dashboard/components-next/icon/SaturnIcon.vue';

const props = defineProps({
  isMobileSidebarOpen: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits([
  'closeKeyShortcutModal',
  'openKeyShortcutModal',
  'showCreateAccountModal',
  'closeMobileSidebar',
]);

const { accountScopedRoute } = useAccount();
const store = useStore();
const searchShortcut = useKbd([`$mod`, 'k']);
const { t } = useI18n();

const toggleShortcutModalFn = show => {
  if (show) {
    emit('openKeyShortcutModal');
  } else {
    emit('closeKeyShortcutModal');
  }
};

useSidebarKeyboardShortcuts(toggleShortcutModalFn);

// We're using localStorage to store the expanded item in the sidebar
// This helps preserve context when navigating between portal and dashboard layouts
// and also when the user refreshes the page
const expandedItem = useStorage(
  'next-sidebar-expanded-item',
  null,
  sessionStorage
);

const setExpandedItem = name => {
  expandedItem.value = expandedItem.value === name ? null : name;
};
provideSidebarContext({
  expandedItem,
  setExpandedItem,
});

const inboxes = useMapGetter('inboxes/getInboxes');
const labels = useMapGetter('labels/getLabelsOnSidebar');
const teams = useMapGetter('teams/getMyTeams');
const contactCustomViews = useMapGetter('customViews/getContactCustomViews');
const conversationCustomViews = useMapGetter(
  'customViews/getConversationCustomViews'
);

onMounted(() => {
  store.dispatch('labels/get');
  store.dispatch('inboxes/get');
  store.dispatch('notifications/unReadCount');
  store.dispatch('teams/get');
  store.dispatch('attributes/get');
  store.dispatch('customViews/get', 'conversation');
  store.dispatch('customViews/get', 'contact');
});

const sortedInboxes = computed(() =>
  inboxes.value.slice().sort((a, b) => a.name.localeCompare(b.name))
);

const closeMobileSidebar = () => {
  if (!props.isMobileSidebarOpen) return;
  emit('closeMobileSidebar');
};

const newReportRoutes = () => [
  {
    name: 'Reports Agent',
    label: t('SIDEBAR.REPORTS_AGENT'),
    to: accountScopedRoute('agent_reports_index'),
    activeOn: ['agent_reports_show'],
  },
  {
    name: 'Reports Label',
    label: t('SIDEBAR.REPORTS_LABEL'),
    to: accountScopedRoute('label_reports_index'),
  },
  {
    name: 'Reports Inbox',
    label: t('SIDEBAR.REPORTS_INBOX'),
    to: accountScopedRoute('inbox_reports_index'),
    activeOn: ['inbox_reports_show'],
  },
  {
    name: 'Reports Team',
    label: t('SIDEBAR.REPORTS_TEAM'),
    to: accountScopedRoute('team_reports_index'),
    activeOn: ['team_reports_show'],
  },
];

const reportRoutes = computed(() => newReportRoutes());

const menuItems = computed(() => {
  return [
    {
      name: 'Inbox',
      label: t('SIDEBAR.INBOX'),
      icon: h(
        'svg',
        {
          class: 'size-4',
          viewBox: '0 0 24 24',
          fill: 'none',
          xmlns: 'http://www.w3.org/2000/svg',
        },
        [
          h('path', {
            d: 'M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z',
            stroke: 'currentColor',
            'stroke-width': '1.5',
            'stroke-linecap': 'round',
            'stroke-linejoin': 'round',
          }),
          h('polyline', {
            points: '22,6 12,13 2,6',
            stroke: 'currentColor',
            'stroke-width': '1.5',
            'stroke-linecap': 'round',
            'stroke-linejoin': 'round',
          }),
        ]
      ),
      to: accountScopedRoute('inbox_view'),
      activeOn: ['inbox_view', 'inbox_view_conversation'],
      getterKeys: {
        count: 'notifications/getUnreadCount',
      },
    },
    {
      name: 'Conversation',
      label: t('SIDEBAR.CONVERSATIONS'),
      icon: h(
        'svg',
        {
          class: 'size-4',
          viewBox: '0 0 24 24',
          fill: 'none',
          xmlns: 'http://www.w3.org/2000/svg',
        },
        [
          h('path', {
            d: 'M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z',
            stroke: 'currentColor',
            'stroke-width': '1.5',
            'stroke-linecap': 'round',
            'stroke-linejoin': 'round',
          }),
        ]
      ),
      children: [
        {
          name: 'All',
          label: t('SIDEBAR.ALL_CONVERSATIONS'),
          activeOn: ['inbox_conversation'],
          to: accountScopedRoute('home'),
        },
        {
          name: 'Mentions',
          label: t('SIDEBAR.MENTIONED_CONVERSATIONS'),
          activeOn: ['conversation_through_mentions'],
          to: accountScopedRoute('conversation_mentions'),
        },
        {
          name: 'Unattended',
          activeOn: ['conversation_through_unattended'],
          label: t('SIDEBAR.UNATTENDED_CONVERSATIONS'),
          to: accountScopedRoute('conversation_unattended'),
        },
        {
          name: 'Folders',
          label: t('SIDEBAR.CUSTOM_VIEWS_FOLDER'),
          icon: h(
            'svg',
            {
              class: 'size-4',
              viewBox: '0 0 24 24',
              fill: 'none',
              xmlns: 'http://www.w3.org/2000/svg',
            },
            [
              h('path', {
                d: 'M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z',
                stroke: 'currentColor',
                'stroke-width': '1.5',
                'stroke-linecap': 'round',
                'stroke-linejoin': 'round',
              }),
            ]
          ),
          activeOn: ['conversations_through_folders'],
          children: conversationCustomViews.value.map(view => ({
            name: `${view.name}-${view.id}`,
            label: view.name,
            to: accountScopedRoute('folder_conversations', { id: view.id }),
          })),
        },
        {
          name: 'Teams',
          label: t('SIDEBAR.TEAMS'),
          icon: h(
            'svg',
            {
              class: 'size-4',
              viewBox: '0 0 24 24',
              fill: 'none',
              xmlns: 'http://www.w3.org/2000/svg',
            },
            [
              h('path', {
                d: 'M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2',
                stroke: 'currentColor',
                'stroke-width': '1.5',
                'stroke-linecap': 'round',
                'stroke-linejoin': 'round',
              }),
              h('circle', {
                cx: '9',
                cy: '7',
                r: '4',
                stroke: 'currentColor',
                'stroke-width': '1.5',
                'stroke-linecap': 'round',
                'stroke-linejoin': 'round',
              }),
              h('path', {
                d: 'M23 21v-2a4 4 0 0 0-3-3.87',
                stroke: 'currentColor',
                'stroke-width': '1.5',
                'stroke-linecap': 'round',
                'stroke-linejoin': 'round',
              }),
              h('path', {
                d: 'M16 3.13a4 4 0 0 1 0 7.75',
                stroke: 'currentColor',
                'stroke-width': '1.5',
                'stroke-linecap': 'round',
                'stroke-linejoin': 'round',
              }),
            ]
          ),
          activeOn: ['conversations_through_team'],
          children: teams.value.map(team => ({
            name: `${team.name}-${team.id}`,
            label: team.name,
            to: accountScopedRoute('team_conversations', { teamId: team.id }),
          })),
        },
        {
          name: 'Channels',
          label: t('SIDEBAR.CHANNELS'),
          icon: h(
            'svg',
            {
              class: 'size-4',
              viewBox: '0 0 24 24',
              fill: 'none',
              xmlns: 'http://www.w3.org/2000/svg',
            },
            [
              h('path', {
                d: 'M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z',
                stroke: 'currentColor',
                'stroke-width': '1.5',
                'stroke-linecap': 'round',
                'stroke-linejoin': 'round',
              }),
              h('polyline', {
                points: '22,6 12,13 2,6',
                stroke: 'currentColor',
                'stroke-width': '1.5',
                'stroke-linecap': 'round',
                'stroke-linejoin': 'round',
              }),
            ]
          ),
          activeOn: ['conversation_through_inbox'],
          children: sortedInboxes.value.map(inbox => ({
            name: `${inbox.name}-${inbox.id}`,
            label: inbox.name,
            to: accountScopedRoute('inbox_dashboard', { inbox_id: inbox.id }),
            component: leafProps =>
              h(ChannelLeaf, {
                label: leafProps.label,
                active: leafProps.active,
                inbox,
              }),
          })),
        },
        {
          name: 'Labels',
          label: t('SIDEBAR.LABELS'),
          icon: h(
            'svg',
            {
              class: 'size-4',
              viewBox: '0 0 24 24',
              fill: 'none',
              xmlns: 'http://www.w3.org/2000/svg',
            },
            [
              h('path', {
                d: 'M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z',
                stroke: 'currentColor',
                'stroke-width': '1.5',
                'stroke-linecap': 'round',
                'stroke-linejoin': 'round',
              }),
              h('line', {
                x1: '7',
                y1: '7',
                x2: '7.01',
                y2: '7',
                stroke: 'currentColor',
                'stroke-width': '1.5',
                'stroke-linecap': 'round',
                'stroke-linejoin': 'round',
              }),
            ]
          ),
          activeOn: ['conversations_through_label'],
          children: labels.value.map(label => ({
            name: `${label.title}-${label.id}`,
            label: label.title,
            icon: h('span', {
              class: `size-[12px] ring-1 ring-n-alpha-1 dark:ring-white/20 ring-inset rounded-sm`,
              style: { backgroundColor: label.color },
            }),
            to: accountScopedRoute('label_conversations', {
              label: label.title,
            }),
          })),
        },
      ],
    },
    {
      name: 'Captain',
      icon: h(
        'svg',
        {
          class: 'size-4',
          viewBox: '0 0 24 24',
          fill: 'none',
          xmlns: 'http://www.w3.org/2000/svg',
        },
        [
          h('path', {
            d: 'M12 2L2 7l10 5 10-5-10-5z',
            stroke: 'currentColor',
            'stroke-width': '1.5',
            'stroke-linecap': 'round',
            'stroke-linejoin': 'round',
          }),
          h('path', {
            d: 'M2 17l10 5 10-5',
            stroke: 'currentColor',
            'stroke-width': '1.5',
            'stroke-linecap': 'round',
            'stroke-linejoin': 'round',
          }),
          h('path', {
            d: 'M2 12l10 5 10-5',
            stroke: 'currentColor',
            'stroke-width': '1.5',
            'stroke-linecap': 'round',
            'stroke-linejoin': 'round',
          }),
        ]
      ),
      label: t('SIDEBAR.CAPTAIN'),
      children: [
        {
          name: 'Assistants',
          label: t('SIDEBAR.CAPTAIN_ASSISTANTS'),
          to: accountScopedRoute('captain_assistants_index'),
        },
        {
          name: 'Documents',
          label: t('SIDEBAR.CAPTAIN_DOCUMENTS'),
          to: accountScopedRoute('captain_documents_index'),
        },
        {
          name: 'Responses',
          label: t('SIDEBAR.CAPTAIN_RESPONSES'),
          to: accountScopedRoute('captain_responses_index'),
        },
        {
          name: 'Tools',
          label: t('SIDEBAR.CAPTAIN_TOOLS'),
          to: accountScopedRoute('captain_tools_index'),
        },
      ],
    },
    {
      name: 'Saturn',
      icon: h(SaturnIcon, { class: 'size-4' }),
      label: t('SIDEBAR.SATURN'),
      to: accountScopedRoute('saturn_assistants_index'),
      featureFlag: null,
      children: [
        {
          name: 'Assistants',
          label: t('SIDEBAR.SATURN_ASSISTANTS'),
          to: accountScopedRoute('saturn_assistants_index'),
        },
        {
          name: 'Documents',
          label: t('SIDEBAR.SATURN_DOCUMENTS'),
          to: accountScopedRoute('saturn_documents_index'),
        },
        {
          name: 'Responses',
          label: t('SIDEBAR.SATURN_RESPONSES'),
          to: accountScopedRoute('saturn_responses_index'),
        },
      ],
    },
    {
      name: 'Contacts',
      label: t('SIDEBAR.CONTACTS'),
      icon: h(
        'svg',
        {
          class: 'size-4',
          viewBox: '0 0 24 24',
          fill: 'none',
          xmlns: 'http://www.w3.org/2000/svg',
        },
        [
          h('path', {
            d: 'M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2',
            stroke: 'currentColor',
            'stroke-width': '1.5',
            'stroke-linecap': 'round',
            'stroke-linejoin': 'round',
          }),
          h('circle', {
            cx: '9',
            cy: '7',
            r: '4',
            stroke: 'currentColor',
            'stroke-width': '1.5',
            'stroke-linecap': 'round',
            'stroke-linejoin': 'round',
          }),
          h('path', {
            d: 'M23 21v-2a4 4 0 0 0-3-3.87',
            stroke: 'currentColor',
            'stroke-width': '1.5',
            'stroke-linecap': 'round',
            'stroke-linejoin': 'round',
          }),
          h('path', {
            d: 'M16 3.13a4 4 0 0 1 0 7.75',
            stroke: 'currentColor',
            'stroke-width': '1.5',
            'stroke-linecap': 'round',
            'stroke-linejoin': 'round',
          }),
        ]
      ),
      children: [
        {
          name: 'All Contacts',
          label: t('SIDEBAR.ALL_CONTACTS'),
          to: accountScopedRoute(
            'contacts_dashboard_index',
            {},
            { page: 1, search: undefined }
          ),
          activeOn: ['contacts_dashboard_index', 'contacts_edit'],
        },
        {
          name: 'Active',
          label: t('SIDEBAR.ACTIVE'),
          to: accountScopedRoute('contacts_dashboard_active'),
          activeOn: ['contacts_dashboard_active'],
        },
        {
          name: 'Segments',
          icon: h(
            'svg',
            {
              class: 'size-4',
              viewBox: '0 0 24 24',
              fill: 'none',
              xmlns: 'http://www.w3.org/2000/svg',
            },
            [
              h('path', {
                d: 'M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2',
                stroke: 'currentColor',
                'stroke-width': '1.5',
                'stroke-linecap': 'round',
                'stroke-linejoin': 'round',
              }),
              h('circle', {
                cx: '9',
                cy: '7',
                r: '4',
                stroke: 'currentColor',
                'stroke-width': '1.5',
                'stroke-linecap': 'round',
                'stroke-linejoin': 'round',
              }),
              h('path', {
                d: 'M23 21v-2a4 4 0 0 0-3-3.87',
                stroke: 'currentColor',
                'stroke-width': '1.5',
                'stroke-linecap': 'round',
                'stroke-linejoin': 'round',
              }),
              h('path', {
                d: 'M16 3.13a4 4 0 0 1 0 7.75',
                stroke: 'currentColor',
                'stroke-width': '1.5',
                'stroke-linecap': 'round',
                'stroke-linejoin': 'round',
              }),
            ]
          ),
          label: t('SIDEBAR.CUSTOM_VIEWS_SEGMENTS'),
          children: contactCustomViews.value.map(view => ({
            name: `${view.name}-${view.id}`,
            label: view.name,
            to: accountScopedRoute(
              'contacts_dashboard_segments_index',
              { segmentId: view.id },
              { page: 1 }
            ),
            activeOn: [
              'contacts_dashboard_segments_index',
              'contacts_edit_segment',
            ],
          })),
        },
        {
          name: 'Tagged With',
          icon: h(
            'svg',
            {
              class: 'size-4',
              viewBox: '0 0 24 24',
              fill: 'none',
              xmlns: 'http://www.w3.org/2000/svg',
            },
            [
              h('path', {
                d: 'M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z',
                stroke: 'currentColor',
                'stroke-width': '1.5',
                'stroke-linecap': 'round',
                'stroke-linejoin': 'round',
              }),
              h('line', {
                x1: '7',
                y1: '7',
                x2: '7.01',
                y2: '7',
                stroke: 'currentColor',
                'stroke-width': '1.5',
                'stroke-linecap': 'round',
                'stroke-linejoin': 'round',
              }),
            ]
          ),
          label: t('SIDEBAR.TAGGED_WITH'),
          children: labels.value.map(label => ({
            name: `${label.title}-${label.id}`,
            label: label.title,
            icon: h('span', {
              class: `size-[12px] ring-1 ring-n-alpha-1 dark:ring-white/20 ring-inset rounded-sm`,
              style: { backgroundColor: label.color },
            }),
            to: accountScopedRoute(
              'contacts_dashboard_labels_index',
              { label: label.title },
              { page: 1, search: undefined }
            ),
            activeOn: [
              'contacts_dashboard_labels_index',
              'contacts_edit_label',
            ],
          })),
        },
      ],
    },
    {
      name: 'Reports',
      label: t('SIDEBAR.REPORTS'),
      icon: h(
        'svg',
        {
          class: 'size-4',
          viewBox: '0 0 24 24',
          fill: 'none',
          xmlns: 'http://www.w3.org/2000/svg',
        },
        [
          h('polyline', {
            points: '22 6 13.5 14.5 8.5 9.5 2 16',
            stroke: 'currentColor',
            'stroke-width': '1.5',
            'stroke-linecap': 'round',
            'stroke-linejoin': 'round',
          }),
          h('polyline', {
            points: '16 6 22 6 22 12',
            stroke: 'currentColor',
            'stroke-width': '1.5',
            'stroke-linecap': 'round',
            'stroke-linejoin': 'round',
          }),
        ]
      ),
      children: [
        {
          name: 'Report Overview',
          label: t('SIDEBAR.REPORTS_OVERVIEW'),
          to: accountScopedRoute('account_overview_reports'),
        },
        {
          name: 'Report Conversation',
          label: t('SIDEBAR.REPORTS_CONVERSATION'),
          to: accountScopedRoute('conversation_reports'),
        },
        ...reportRoutes.value,
        {
          name: 'Reports CSAT',
          label: t('SIDEBAR.CSAT'),
          to: accountScopedRoute('csat_reports'),
        },
        {
          name: 'Reports SLA',
          label: t('SIDEBAR.REPORTS_SLA'),
          to: accountScopedRoute('sla_reports'),
        },
        {
          name: 'Reports Bot',
          label: t('SIDEBAR.REPORTS_BOT'),
          to: accountScopedRoute('bot_reports'),
        },
      ],
    },
    {
      name: 'Campaigns',
      label: t('SIDEBAR.CAMPAIGNS'),
      icon: h(
        'svg',
        {
          class: 'size-4',
          viewBox: '0 0 24 24',
          fill: 'none',
          xmlns: 'http://www.w3.org/2000/svg',
        },
        [
          h('path', {
            d: 'M3 11c0-1.1.9-2 2-2h4a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-9z',
            stroke: 'currentColor',
            'stroke-width': '1.5',
            'stroke-linecap': 'round',
            'stroke-linejoin': 'round',
          }),
          h('path', {
            d: 'M7 11V6a2 2 0 0 1 2-2h6a2 2 0 0 1 2 2v5',
            stroke: 'currentColor',
            'stroke-width': '1.5',
            'stroke-linecap': 'round',
            'stroke-linejoin': 'round',
          }),
          h('path', {
            d: 'M11 11v9a2 2 0 0 0 2 2h4a2 2 0 0 0 2-2v-9',
            stroke: 'currentColor',
            'stroke-width': '1.5',
            'stroke-linecap': 'round',
            'stroke-linejoin': 'round',
          }),
        ]
      ),
      children: [
        {
          name: 'Live chat',
          label: t('SIDEBAR.LIVE_CHAT'),
          to: accountScopedRoute('campaigns_livechat_index'),
        },
        {
          name: 'SMS',
          label: t('SIDEBAR.SMS'),
          to: accountScopedRoute('campaigns_sms_index'),
        },
        {
          name: 'WhatsApp',
          label: t('SIDEBAR.WHATSAPP'),
          to: accountScopedRoute('campaigns_whatsapp_index'),
        },
      ],
    },
    {
      name: 'Portals',
      label: t('SIDEBAR.HELP_CENTER.TITLE'),
      icon: h(
        'svg',
        {
          class: 'size-4',
          viewBox: '0 0 24 24',
          fill: 'none',
          xmlns: 'http://www.w3.org/2000/svg',
        },
        [
          h('path', {
            d: 'M4 19.5A2.5 2.5 0 0 1 6.5 17H20',
            stroke: 'currentColor',
            'stroke-width': '1.5',
            'stroke-linecap': 'round',
            'stroke-linejoin': 'round',
          }),
          h('path', {
            d: 'M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z',
            stroke: 'currentColor',
            'stroke-width': '1.5',
            'stroke-linecap': 'round',
            'stroke-linejoin': 'round',
          }),
          h('line', {
            x1: '9',
            y1: '7',
            x2: '15',
            y2: '7',
            stroke: 'currentColor',
            'stroke-width': '1.5',
            'stroke-linecap': 'round',
            'stroke-linejoin': 'round',
          }),
          h('line', {
            x1: '9',
            y1: '11',
            x2: '15',
            y2: '11',
            stroke: 'currentColor',
            'stroke-width': '1.5',
            'stroke-linecap': 'round',
            'stroke-linejoin': 'round',
          }),
        ]
      ),
      children: [
        {
          name: 'Articles',
          label: t('SIDEBAR.HELP_CENTER.ARTICLES'),
          activeOn: [
            'portals_articles_index',
            'portals_articles_new',
            'portals_articles_edit',
          ],
          to: accountScopedRoute('portals_index', {
            navigationPath: 'portals_articles_index',
          }),
        },
        {
          name: 'Categories',
          label: t('SIDEBAR.HELP_CENTER.CATEGORIES'),
          activeOn: [
            'portals_categories_index',
            'portals_categories_articles_index',
            'portals_categories_articles_edit',
          ],
          to: accountScopedRoute('portals_index', {
            navigationPath: 'portals_categories_index',
          }),
        },
        {
          name: 'Locales',
          label: t('SIDEBAR.HELP_CENTER.LOCALES'),
          activeOn: ['portals_locales_index'],
          to: accountScopedRoute('portals_index', {
            navigationPath: 'portals_locales_index',
          }),
        },
        {
          name: 'Settings',
          label: t('SIDEBAR.HELP_CENTER.SETTINGS'),
          activeOn: ['portals_settings_index'],
          to: accountScopedRoute('portals_index', {
            navigationPath: 'portals_settings_index',
          }),
        },
      ],
    },
    {
      name: 'Settings',
      label: t('SIDEBAR.SETTINGS'),
      icon: 'i-lucide-bolt',
      children: [
        {
          name: 'Settings Account Settings',
          label: t('SIDEBAR.ACCOUNT_SETTINGS'),
          icon: 'i-lucide-briefcase',
          to: accountScopedRoute('general_settings_index'),
        },
        {
          name: 'Settings Agents',
          label: t('SIDEBAR.AGENTS'),
          icon: 'i-lucide-square-user',
          to: accountScopedRoute('agent_list'),
        },
        {
          name: 'Settings Teams',
          label: t('SIDEBAR.TEAMS'),
          icon: 'i-lucide-users',
          to: accountScopedRoute('settings_teams_list'),
        },
        {
          name: 'Settings Agent Assignment',
          label: t('SIDEBAR.AGENT_ASSIGNMENT'),
          icon: 'i-lucide-user-cog',
          to: accountScopedRoute('assignment_policy_index'),
        },
        {
          name: 'Settings Inboxes',
          label: t('SIDEBAR.INBOXES'),
          icon: 'i-lucide-inbox',
          to: accountScopedRoute('settings_inbox_list'),
        },
        {
          name: 'Settings Labels',
          label: t('SIDEBAR.LABELS'),
          icon: 'i-lucide-tags',
          to: accountScopedRoute('labels_list'),
        },
        {
          name: 'Settings Custom Attributes',
          label: t('SIDEBAR.CUSTOM_ATTRIBUTES'),
          icon: 'i-lucide-code',
          to: accountScopedRoute('attributes_list'),
        },
        {
          name: 'Settings Automation',
          label: t('SIDEBAR.AUTOMATION'),
          icon: 'i-lucide-workflow',
          to: accountScopedRoute('automation_list'),
        },
        {
          name: 'Settings Agent Bots',
          label: t('SIDEBAR.AGENT_BOTS'),
          icon: 'i-lucide-bot',
          to: accountScopedRoute('agent_bots'),
        },
        {
          name: 'Settings Macros',
          label: t('SIDEBAR.MACROS'),
          icon: 'i-lucide-toy-brick',
          to: accountScopedRoute('macros_wrapper'),
        },
        {
          name: 'Settings Canned Responses',
          label: t('SIDEBAR.CANNED_RESPONSES'),
          icon: 'i-lucide-message-square-quote',
          to: accountScopedRoute('canned_list'),
        },
        {
          name: 'Settings Integrations',
          label: t('SIDEBAR.INTEGRATIONS'),
          icon: 'i-lucide-blocks',
          to: accountScopedRoute('settings_applications'),
        },
        {
          name: 'Settings Audit Logs',
          label: t('SIDEBAR.AUDIT_LOGS'),
          icon: 'i-lucide-briefcase',
          to: accountScopedRoute('auditlogs_list'),
        },
        {
          name: 'Settings Custom Roles',
          label: t('SIDEBAR.CUSTOM_ROLES'),
          icon: 'i-lucide-shield-plus',
          to: accountScopedRoute('custom_roles_list'),
        },
        {
          name: 'Settings Sla',
          label: t('SIDEBAR.SLA'),
          icon: 'i-lucide-clock-alert',
          to: accountScopedRoute('sla_list'),
        },
        {
          name: 'Settings Security',
          label: t('SIDEBAR.SECURITY'),
          icon: 'i-lucide-shield',
          to: accountScopedRoute('security_settings_index'),
        },
        {
          name: 'Settings Billing',
          label: t('SIDEBAR.BILLING'),
          icon: 'i-lucide-credit-card',
          to: accountScopedRoute('billing_settings_index'),
        },
      ],
    },
  ];
});
</script>

<template>
  <aside
    v-on-click-outside="[
      closeMobileSidebar,
      { ignore: ['#mobile-sidebar-launcher'] },
    ]"
    class="bg-n-solid-2 rtl:border-l ltr:border-r border-n-weak flex flex-col text-sm pb-1 fixed top-0 ltr:left-0 rtl:right-0 h-full z-40 transition-transform duration-200 ease-in-out md:static w-[200px] basis-[200px] md:flex-shrink-0 md:ltr:translate-x-0 md:rtl:-translate-x-0"
    :class="[
      {
        'shadow-lg md:shadow-none': isMobileSidebarOpen,
        'ltr:-translate-x-full rtl:translate-x-full': !isMobileSidebarOpen,
      },
    ]"
  >
    <section class="grid gap-2 mt-2 mb-4">
      <div class="flex items-center min-w-0 gap-2 px-2">
        <div class="grid flex-shrink-0 size-6 place-content-center">
          <Logo class="size-4" />
        </div>
        <div class="flex-shrink-0 w-px h-3 bg-n-strong" />
        <SidebarAccountSwitcher
          class="flex-grow min-w-0 -mx-1"
          @show-create-account-modal="emit('showCreateAccountModal')"
        />
      </div>
      <div class="flex gap-2 px-2">
        <RouterLink
          :to="{ name: 'search' }"
          class="flex items-center w-full gap-2 px-2 py-1 rounded-lg h-7 outline outline-1 outline-n-weak bg-n-solid-3 dark:bg-n-black/30"
        >
          <span class="flex-shrink-0 i-lucide-search size-4 text-n-slate-11" />
          <span class="flex-grow text-left">
            {{ t('COMBOBOX.SEARCH_PLACEHOLDER') }}
          </span>
          <span
            class="hidden tracking-wide pointer-events-none select-none text-n-slate-10"
          >
            {{ searchShortcut }}
          </span>
        </RouterLink>
        <ComposeConversation align-position="right">
          <template #trigger="{ toggle }">
            <Button
              icon="i-lucide-pen-line"
              color="slate"
              size="sm"
              class="!h-7 !bg-n-solid-3 dark:!bg-n-black/30 !outline-n-weak !text-n-slate-11"
              @click="toggle"
            />
          </template>
        </ComposeConversation>
      </div>
    </section>
    <nav class="grid flex-grow gap-2 px-2 pb-5 overflow-y-scroll no-scrollbar">
      <ul class="flex flex-col gap-1.5 m-0 list-none">
        <SidebarGroup
          v-for="item in menuItems"
          :key="item.name"
          v-bind="item"
        />
      </ul>
    </nav>
    <section
      class="p-1 border-t border-n-weak shadow-[0px_-2px_4px_0px_rgba(27,28,29,0.02)] flex-shrink-0 flex justify-between gap-2 items-center"
    >
      <SidebarProfileMenu
        @open-key-shortcut-modal="emit('openKeyShortcutModal')"
      />
    </section>
  </aside>
</template>

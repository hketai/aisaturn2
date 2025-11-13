import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { INSTALLATION_TYPES } from 'dashboard/constants/installationTypes';
import { frontendURL } from '../../../helper/URLHelper';
import AssistantIndex from './assistants/Index.vue';
import AssistantEdit from './assistants/Edit.vue';
import AssistantInboxesIndex from './assistants/inboxes/Index.vue';
import AssistantGuardrailsIndex from './assistants/guardrails/Index.vue';
import AssistantGuidelinesIndex from './assistants/guidelines/Index.vue';
import AssistantScenariosIndex from './assistants/scenarios/Index.vue';
import AssistantWorkingHoursIndex from './assistants/workingHours/Index.vue';
import AssistantHandoffIndex from './assistants/handoff/Index.vue';
import DocumentsIndex from './documents/Index.vue';
import ResponsesIndex from './responses/Index.vue';
import CustomToolsIndex from './tools/Index.vue';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/saturn/assistants'),
    component: AssistantIndex,
    name: 'saturn_assistants_index',
    meta: {
      permissions: ['administrator', 'agent'],
      featureFlag: FEATURE_FLAGS.SATURN,
      installationTypes: [
        INSTALLATION_TYPES.CLOUD,
        INSTALLATION_TYPES.ENTERPRISE,
        INSTALLATION_TYPES.COMMUNITY,
      ],
    },
  },
  {
    path: frontendURL('accounts/:accountId/saturn/assistants/:assistantId'),
    component: AssistantEdit,
    name: 'saturn_assistants_edit',
    meta: {
      permissions: ['administrator', 'agent'],
      featureFlag: FEATURE_FLAGS.SATURN,
      installationTypes: [
        INSTALLATION_TYPES.CLOUD,
        INSTALLATION_TYPES.ENTERPRISE,
        INSTALLATION_TYPES.COMMUNITY,
      ],
    },
  },
  {
    path: frontendURL(
      'accounts/:accountId/saturn/assistants/:assistantId/inboxes'
    ),
    component: AssistantInboxesIndex,
    name: 'saturn_assistants_inboxes_index',
    meta: {
      permissions: ['administrator', 'agent'],
      featureFlag: FEATURE_FLAGS.SATURN,
      installationTypes: [
        INSTALLATION_TYPES.CLOUD,
        INSTALLATION_TYPES.ENTERPRISE,
        INSTALLATION_TYPES.COMMUNITY,
      ],
    },
  },
  {
    path: frontendURL(
      'accounts/:accountId/saturn/assistants/:assistantId/guardrails'
    ),
    component: AssistantGuardrailsIndex,
    name: 'saturn_assistants_guardrails_index',
    meta: {
      permissions: ['administrator', 'agent'],
      featureFlag: FEATURE_FLAGS.SATURN,
      installationTypes: [
        INSTALLATION_TYPES.CLOUD,
        INSTALLATION_TYPES.ENTERPRISE,
        INSTALLATION_TYPES.COMMUNITY,
      ],
    },
  },
  {
    path: frontendURL(
      'accounts/:accountId/saturn/assistants/:assistantId/scenarios'
    ),
    component: AssistantScenariosIndex,
    name: 'saturn_assistants_scenarios_index',
    meta: {
      permissions: ['administrator', 'agent'],
      featureFlag: FEATURE_FLAGS.SATURN,
      installationTypes: [
        INSTALLATION_TYPES.CLOUD,
        INSTALLATION_TYPES.ENTERPRISE,
        INSTALLATION_TYPES.COMMUNITY,
      ],
    },
  },
  {
    path: frontendURL(
      'accounts/:accountId/saturn/assistants/:assistantId/guidelines'
    ),
    component: AssistantGuidelinesIndex,
    name: 'saturn_assistants_guidelines_index',
    meta: {
      permissions: ['administrator', 'agent'],
      featureFlag: FEATURE_FLAGS.SATURN,
      installationTypes: [
        INSTALLATION_TYPES.CLOUD,
        INSTALLATION_TYPES.ENTERPRISE,
        INSTALLATION_TYPES.COMMUNITY,
      ],
    },
  },
  {
    path: frontendURL(
      'accounts/:accountId/saturn/assistants/:assistantId/working-hours'
    ),
    component: AssistantWorkingHoursIndex,
    name: 'saturn_assistants_working_hours_index',
    meta: {
      permissions: ['administrator', 'agent'],
      featureFlag: FEATURE_FLAGS.SATURN,
      installationTypes: [
        INSTALLATION_TYPES.CLOUD,
        INSTALLATION_TYPES.ENTERPRISE,
        INSTALLATION_TYPES.COMMUNITY,
      ],
    },
  },
  {
    path: frontendURL(
      'accounts/:accountId/saturn/assistants/:assistantId/handoff'
    ),
    component: AssistantHandoffIndex,
    name: 'saturn_assistants_handoff_index',
    meta: {
      permissions: ['administrator', 'agent'],
      featureFlag: FEATURE_FLAGS.SATURN,
      installationTypes: [
        INSTALLATION_TYPES.CLOUD,
        INSTALLATION_TYPES.ENTERPRISE,
        INSTALLATION_TYPES.COMMUNITY,
      ],
    },
  },
  {
    path: frontendURL('accounts/:accountId/saturn/documents'),
    component: DocumentsIndex,
    name: 'saturn_documents_index',
    meta: {
      permissions: ['administrator', 'agent'],
      featureFlag: FEATURE_FLAGS.SATURN,
      installationTypes: [
        INSTALLATION_TYPES.CLOUD,
        INSTALLATION_TYPES.ENTERPRISE,
        INSTALLATION_TYPES.COMMUNITY,
      ],
    },
  },
  {
    path: frontendURL('accounts/:accountId/saturn/responses'),
    component: ResponsesIndex,
    name: 'saturn_responses_index',
    meta: {
      permissions: ['administrator', 'agent'],
      featureFlag: FEATURE_FLAGS.SATURN,
      installationTypes: [
        INSTALLATION_TYPES.CLOUD,
        INSTALLATION_TYPES.ENTERPRISE,
        INSTALLATION_TYPES.COMMUNITY,
      ],
    },
  },
  {
    path: frontendURL('accounts/:accountId/saturn/tools'),
    component: CustomToolsIndex,
    name: 'saturn_tools_index',
    meta: {
      permissions: ['administrator', 'agent'],
      featureFlag: FEATURE_FLAGS.SATURN,
      installationTypes: [
        INSTALLATION_TYPES.CLOUD,
        INSTALLATION_TYPES.ENTERPRISE,
        INSTALLATION_TYPES.COMMUNITY,
      ],
    },
  },
];

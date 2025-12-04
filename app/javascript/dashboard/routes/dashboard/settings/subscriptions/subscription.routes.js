import { frontendURL } from 'dashboard/helper/URLHelper';
import { ROLES } from 'dashboard/constants/permissions';
import SettingsWrapper from '../SettingsWrapper.vue';
import Index from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/subscriptions'),
      component: SettingsWrapper,
      meta: {
        permissions: [...ROLES],
      },
      children: [
        {
          path: '',
          name: 'subscriptions_index',
          component: Index,
          meta: {
            permissions: [...ROLES],
          },
        },
      ],
    },
  ],
};

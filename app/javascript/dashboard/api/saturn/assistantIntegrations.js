/* global axios */

import ApiClient from '../ApiClient';

class SaturnAssistantIntegrationsAPI extends ApiClient {
  constructor() {
    super('saturn/assistants', { accountScoped: true });
  }

  getIntegrations(assistantId) {
    return axios.get(`${this.url}/${assistantId}/assistant_integrations`);
  }

  toggleIntegration(assistantId, integrationType, enabled) {
    return axios.post(`${this.url}/${assistantId}/assistant_integrations/toggle`, {
      integration_type: integrationType,
      enabled,
    });
  }

  enableIntegration(assistantId, integrationType) {
    return axios.post(`${this.url}/${assistantId}/assistant_integrations`, {
      integration_type: integrationType,
      enabled: true,
    });
  }

  disableIntegration(assistantId, integrationType) {
    return axios.post(`${this.url}/${assistantId}/assistant_integrations`, {
      integration_type: integrationType,
      enabled: false,
    });
  }
}

export default new SaturnAssistantIntegrationsAPI();


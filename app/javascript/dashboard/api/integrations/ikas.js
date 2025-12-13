/* global axios */

import ApiClient from '../ApiClient';

class IkasAPI extends ApiClient {
  constructor() {
    super('integrations/ikas', { accountScoped: true });
  }

  getHook() {
    return axios.get(`${this.url}`);
  }

  // Initiates OAuth flow - returns auth URL to redirect to
  initiateAuth(storeName) {
    return axios.post(`${this.url}/auth`, {
      store_name: storeName,
    });
  }

  disconnect() {
    return axios.delete(`${this.url}`);
  }

  testConnection() {
    return axios.get(`${this.url}/test`);
  }

  syncProducts(incremental = false) {
    return axios.post(`${this.url}/sync_products`, { incremental });
  }

  getSyncStatus() {
    return axios.get(`${this.url}/sync_status`);
  }

  updateSettings(settings) {
    return axios.patch(`${this.url}/update_settings`, { settings });
  }
}

export default new IkasAPI();


/* global axios */

import ApiClient from '../ApiClient';

class ShopifyAPI extends ApiClient {
  constructor() {
    super('integrations/shopify', { accountScoped: true });
  }

  getHook() {
    return axios.get(`${this.url}`);
  }

  getOrders(contactId) {
    return axios.get(`${this.url}/orders`, {
      params: { contact_id: contactId },
    });
  }

  connectWithAccessKey({ shopDomain, accessKey }) {
    return axios.post(`${this.url}/connect`, {
      shop_domain: shopDomain,
      access_token: accessKey,
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

  getProducts(query, limit = 20) {
    return axios.get(`${this.url}/products`, {
      params: { query, limit },
    });
  }
}

export default new ShopifyAPI();

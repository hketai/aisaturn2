/* global axios */
import ApiClient from '../ApiClient';

class WhatsappWebChannel extends ApiClient {
  constructor() {
    // Don't use accountScoped here, we'll build URLs manually
    super('', { version: 'v1' });
  }

  accountScopedUrl(accountId) {
    // Build URL: /api/v1/accounts/{accountId}
    return `${this.apiVersion}/accounts/${accountId}`;
  }

  create({ accountId, ...params } = {}) {
    return axios.post(
      `${this.accountScopedUrl(accountId)}/whatsapp_web/channels`,
      params
    );
  }

  show({ accountId, channelId } = {}) {
    return axios.get(
      `${this.accountScopedUrl(accountId)}/whatsapp_web/channels/${channelId}`
    );
  }

  update({ accountId, channelId, ...params } = {}) {
    return axios.patch(
      `${this.accountScopedUrl(accountId)}/whatsapp_web/channels/${channelId}`,
      params
    );
  }

  delete({ accountId, channelId } = {}) {
    return axios.delete(
      `${this.accountScopedUrl(accountId)}/whatsapp_web/channels/${channelId}`
    );
  }

  getQrCode({ accountId, channelId } = {}) {
    return axios.get(
      `${this.accountScopedUrl(accountId)}/whatsapp_web/channels/${channelId}/qr_code`
    );
  }

  getStatus({ accountId, channelId } = {}) {
    return axios.get(
      `${this.accountScopedUrl(accountId)}/whatsapp_web/channels/${channelId}/status`
    );
  }

  start({ accountId, channelId } = {}) {
    return axios.post(
      `${this.accountScopedUrl(accountId)}/whatsapp_web/channels/${channelId}/start`
    );
  }

  stop({ accountId, channelId } = {}) {
    return axios.post(
      `${this.accountScopedUrl(accountId)}/whatsapp_web/channels/${channelId}/stop`
    );
  }
}

export default new WhatsappWebChannel();

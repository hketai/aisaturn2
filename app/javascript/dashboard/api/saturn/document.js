/* global axios */
import ApiClient from '../ApiClient';

class SaturnDocument extends ApiClient {
  constructor() {
    super('saturn/assistants', { accountScoped: true });
  }

  get({ page = 1, assistantId } = {}) {
    const url = assistantId
      ? `${this.url}/${assistantId}/documents`
      : `/api/v1/accounts/${this.accountIdFromRoute}/saturn/documents`;

    return axios.get(url, {
      params: {
        page,
      },
    });
  }

  show({ assistantId, id }) {
    return axios.get(`${this.url}/${assistantId}/documents/${id}`);
  }

  create({ assistantId, document } = {}) {
    return axios.post(`${this.url}/${assistantId}/documents`, document, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    });
  }

  update({ assistantId, id }, data = {}) {
    return axios.put(`${this.url}/${assistantId}/documents/${id}`, {
      document: data,
    });
  }

  delete({ assistantId, id }) {
    return axios.delete(`${this.url}/${assistantId}/documents/${id}`);
  }
}

export default new SaturnDocument();

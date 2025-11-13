/* global axios */
import ApiClient from '../ApiClient';

class SaturnResponses extends ApiClient {
  constructor() {
    super('saturn/assistants', { accountScoped: true });
  }

  get({ page = 1, assistantId, status, search } = {}) {
    const url = assistantId
      ? `${this.url}/${assistantId}/responses`
      : `/api/v1/accounts/${this.accountIdFromRoute}/saturn/responses`;

    return axios.get(url, {
      params: {
        page,
        status,
        search,
      },
    });
  }

  show(id) {
    return axios.get(
      `/api/v1/accounts/${this.accountIdFromRoute}/saturn/responses/${id}`
    );
  }

  create({ assistantId, ...data } = {}) {
    return axios.post(`${this.url}/${assistantId}/responses`, {
      response: data,
    });
  }

  update(id, data = {}) {
    return axios.put(
      `/api/v1/accounts/${this.accountIdFromRoute}/saturn/responses/${id}`,
      {
        response: data,
      }
    );
  }

  delete(id) {
    return axios.delete(
      `/api/v1/accounts/${this.accountIdFromRoute}/saturn/responses/${id}`
    );
  }

  approve(id) {
    return this.update(id, { status: 'approved' });
  }

  search({ query } = {}) {
    return axios.get(
      `/api/v1/accounts/${this.accountIdFromRoute}/saturn/responses/search`,
      {
        params: { query },
      }
    );
  }
}

export default new SaturnResponses();

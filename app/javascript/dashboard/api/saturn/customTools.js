/* global axios */
import ApiClient from '../ApiClient';

class SaturnCustomTools extends ApiClient {
  constructor() {
    super('saturn/custom_tools', { accountScoped: true });
  }

  get({ page = 1, searchKey, enabled } = {}) {
    return axios.get(this.url, {
      params: { page, searchKey, enabled },
    });
  }

  show(id) {
    return axios.get(`${this.url}/${id}`);
  }

  create(data = {}) {
    return axios.post(this.url, {
      custom_tool: data,
    });
  }

  update(id, data = {}) {
    return axios.put(`${this.url}/${id}`, {
      custom_tool: data,
    });
  }

  delete(id) {
    return axios.delete(`${this.url}/${id}`);
  }
}

export default new SaturnCustomTools();

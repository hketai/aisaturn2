/* global axios */
import ApiClient from './ApiClient';

class Subscriptions extends ApiClient {
  constructor() {
    super('subscriptions', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }

  show(id) {
    return axios.get(`${this.url}/${id}`);
  }

  current() {
    return axios.get(`${this.url}/current`);
  }

  create(data) {
    return axios.post(this.url, {
      subscription: data,
    });
  }

  update(id, data) {
    return axios.put(`${this.url}/${id}`, {
      subscription: data,
    });
  }

  cancel(id, immediate = false) {
    return axios.post(`${this.url}/${id}/cancel`, {
      immediate,
    });
  }

  limits() {
    return axios.get(`${this.url}/limits`);
  }
}

export default new Subscriptions();

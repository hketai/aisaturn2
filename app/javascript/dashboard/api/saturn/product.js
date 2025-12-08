/* global axios */
import ApiClient from '../ApiClient';

class SaturnProduct extends ApiClient {
  constructor() {
    super('saturn/products', { accountScoped: true });
  }

  get({ page = 1, perPage = 25, source, query } = {}) {
    return axios.get(this.url, {
      params: {
        page,
        per_page: perPage,
        source,
        query,
      },
    });
  }

  show(id) {
    return axios.get(`${this.url}/${id}`);
  }

  create(product) {
    return axios.post(this.url, { product });
  }

  update(id, product) {
    return axios.put(`${this.url}/${id}`, { product });
  }

  delete(id) {
    return axios.delete(`${this.url}/${id}`);
  }
}

export default new SaturnProduct();


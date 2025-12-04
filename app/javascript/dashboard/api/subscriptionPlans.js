/* global axios */
import ApiClient from './ApiClient';

class SubscriptionPlans extends ApiClient {
  constructor() {
    super('subscription_plans', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }

  show(id) {
    return axios.get(`${this.url}/${id}`);
  }
}

export default new SubscriptionPlans();

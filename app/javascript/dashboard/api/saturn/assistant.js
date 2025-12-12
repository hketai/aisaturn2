/* global axios */
import ApiClient from '../ApiClient';

class SaturnAssistant extends ApiClient {
  constructor() {
    super('saturn/assistants', { accountScoped: true });
  }

  get({ page = 1, searchKey, id } = {}) {
    if (id) {
      return axios.get(`${this.url}/${id}`);
    }
    return axios.get(this.url, {
      params: {
        page,
        searchKey,
      },
    });
  }

  show(id) {
    return axios.get(`${this.url}/${id}`);
  }

  create(assistantData) {
    return axios.post(this.url, { assistant: assistantData });
  }

  update({ id, ...assistantData }) {
    return axios.put(`${this.url}/${id}`, { assistant: assistantData });
  }

  delete(id) {
    return axios.delete(`${this.url}/${id}`);
  }

  playground({ assistantId, messageContent, messageHistory, imageBase64 }) {
    return axios.post(`${this.url}/${assistantId}/playground`, {
      message_content: messageContent,
      message_history: messageHistory,
      image_base64: imageBase64,
    });
  }

  updateWorkingHours({ assistantId, workingHours }) {
    return axios.put(`${this.url}/${assistantId}/update_working_hours`, {
      working_hours: workingHours,
    });
  }

  updateHandoffSettings({ assistantId, handoffConfig }) {
    return axios.put(`${this.url}/${assistantId}/update_handoff_settings`, {
      handoff_config: handoffConfig,
    });
  }
}

export default new SaturnAssistant();

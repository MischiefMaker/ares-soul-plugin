import Component from '@ember/component';
import { inject as service } from '@ember/service';

export default Component.extend({
  tagName: '',
  api: service('game-api'),
  isLoading: false,

  didInsertElement() {
    this._super(...arguments);
    this.loadCatalogue();
  },

  async loadCatalogue(query) {
    this.set('isLoading', true);
    try {
      let result = await this.api.requestOne('soulBnbCatalogue', { query });
      this.set('entries', result.entries);
    } finally {
      this.set('isLoading', false);
    }
  },

  actions: {
    search() {
      return this.loadCatalogue(this.query);
    },
    async showDetail(entry) {
      let result = await this.api.requestOne('soulBnb', { reference: entry.id });
      if (!result.error) {
        this.set('detail', result);
      }
    },
    closeDetail() {
      this.set('detail', null);
    }
  }
});

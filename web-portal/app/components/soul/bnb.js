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

  async loadCatalogue() {
    this.set('isLoading', true);
    try {
      let result = await this.api.requestOne('soulBnbCatalogue', {});
      this.set('entries', result.entries);
    } finally {
      this.set('isLoading', false);
    }
  }
});

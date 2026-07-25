import Component from '@ember/component';
import { inject as service } from '@ember/service';

export default Component.extend({
  tagName: '',
  api: service('game-api'),
  isLoading: false,
  showInfo: false,

  didReceiveAttrs() {
    this._super(...arguments);
    this.loadCulminations();
  },

  async loadCulminations() {
    this.set('isLoading', true);
    try {
      let result = await this.api.requestOne('soulCulminations', { character: this.character }, null);
      this.set('entries', result.entries);
    } finally {
      this.set('isLoading', false);
    }
  },

  actions: {
    toggleInfo() {
      this.toggleProperty('showInfo');
    }
  }
});

import Component from '@ember/component';
import { inject as service } from '@ember/service';

export default Component.extend({
  tagName: '',
  api: service('game-api'),
  isLoading: false,

  didReceiveAttrs() {
    this._super(...arguments);
    this.loadSheet();
  },

  async loadSheet() {
    this.set('isLoading', true);
    try {
      let sheet = await this.api.requestOne('soulSheet', { character: this.character });
      this.set('sheet', sheet);
    } finally {
      this.set('isLoading', false);
    }
  }
});

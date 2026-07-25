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
  },

  actions: {
    // entry.explanation is only present when the server judged this viewer
    // authorized to see it (the entry's owner, or manage_soul staff) - see
    // SoulSheetWebHandler#serialize_bnb. A scene-GM or other viewer who can
    // see the Sheet at all still won't get it, by design.
    showBnbDetail(entry) {
      this.set('selectedBnb', entry);
      this.set('bnbModalOpen', true);
    },
    closeBnbDetail() {
      this.set('bnbModalOpen', false);
    }
  }
});

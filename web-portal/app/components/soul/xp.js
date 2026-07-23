import Component from '@ember/component';
import { inject as service } from '@ember/service';

export default Component.extend({
  tagName: '',
  api: service('game-api'),
  isLoading: false,

  didInsertElement() {
    this._super(...arguments);
    this.loadXp();
  },

  async loadXp() {
    this.set('isLoading', true);
    try {
      this.set('xp', await this.api.requestOne('soulXp', {}));
    } finally {
      this.set('isLoading', false);
    }
  },

  actions: {
    async previewSpend(skillKey, amount) {
      let preview = await this.api.requestOne('soulXpSpend', {
        skill_key: skillKey,
        amount
      });
      this.set('spendPreview', preview);
    },

    async confirmSpend(skillKey, amount) {
      let result = await this.api.requestOne('soulXpSpend', {
        skill_key: skillKey,
        amount,
        confirmed: 'true'
      });
      if (!result.error) {
        await this.loadXp();
        this.set('spendPreview', null);
      }
    }
  }
});

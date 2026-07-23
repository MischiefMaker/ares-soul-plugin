import Component from '@ember/component';
import { inject as service } from '@ember/service';

export default Component.extend({
  tagName: '',
  api: service('game-api'),
  isLoading: false,

  didInsertElement() {
    this._super(...arguments);
    this.loadStatus();
  },

  async request(cmd, args) {
    this.set('isLoading', true);
    try {
      let result = await this.api.requestOne(cmd, args || {});
      if (!result.error) {
        this.setProperties({ status: result, selectedCatalogue: null, explanation: null });
      }
    } finally {
      this.set('isLoading', false);
    }
  },

  loadStatus() {
    return this.request('soulChargenStatus', {});
  },

  actions: {
    setResonance(value) {
      return this.request('soulChargenResonance', { value });
    },
    setSkill(skill, event) {
      return this.request('soulChargenSkill', {
        skill_key: skill.key,
        rating: event.target.value
      });
    },
    selectCatalogue(entry) {
      this.set('selectedCatalogue', entry);
    },
    addBnb() {
      if (!this.selectedCatalogue || !this.explanation) {
        return;
      }
      return this.request('soulChargenBnb', {
        reference: this.selectedCatalogue.id,
        level_state: this.selectedLevel || 'minor',
        explanation: this.explanation
      });
    },
    dropBnb(entry) {
      return this.request('soulChargenDrop', { entry_id: entry.id });
    }
  }
});

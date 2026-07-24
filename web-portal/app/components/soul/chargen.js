import Component from '@ember/component';
import { inject as service } from '@ember/service';

export default Component.extend({
  tagName: '',
  api: service('game-api'),
  isLoading: false,

  didInsertElement() {
    this._super(...arguments);
    this.refreshStatus();
  },

  async refreshStatus() {
    let result = await this.api.requestOne('soulChargenStatus', {});
    if (!result.error) {
      this.set('status', result);
    }
  },

  async request(cmd, args) {
    this.set('isLoading', true);
    try {
      let result = await this.api.requestOne(cmd, args || {});
      if (result.error) {
        // Reload from the server so a rejected Skill/Resonance/B&B change
        // (e.g. over budget) doesn't leave a stale, never-actually-saved
        // value showing in a two-way-bound input - but keep the error
        // message visible, which a plain reload would otherwise clear.
        this.set('error', result.error);
        await this.refreshStatus();
      } else {
        this.setProperties({
          status: result, error: null, selectedCatalogue: null, explanation: null
        });
      }
    } finally {
      this.set('isLoading', false);
    }
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
    adjustSkill(skill, delta) {
      let rating = Number(skill.rating || 0) + delta;
      if (rating < 0 || rating > Number(this.get('status.starting_cap'))) {
        return;
      }
      return this.request('soulChargenSkill', {
        skill_key: skill.key,
        rating
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

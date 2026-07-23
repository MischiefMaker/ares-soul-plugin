import Component from '@ember/component';
import { inject as service } from '@ember/service';

export default Component.extend({
  tagName: '',
  api: service('game-api'),
  isLoading: false,

  didReceiveAttrs() {
    this._super(...arguments);
    if (this.isSelf) {
      this.loadXp();
    } else {
      this.setProperties({
        xp: null,
        skills: [],
        spendPreview: null,
        isLoading: false
      });
    }
  },

  async loadXp() {
    this.set('isLoading', true);
    try {
      let [xp, sheet] = await Promise.all([
        this.api.requestOne('soulXp', {}),
        this.api.requestOne('soulSheet', { character: this.character })
      ]);
      if (xp.error || sheet.error) {
        return;
      }

      let skills = [];
      (sheet.aspects || []).forEach((aspect) => {
        (aspect.skills || []).forEach((skill) => {
          skills.push(skill);
        });
      });

      this.setProperties({ xp, skills });
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
      if (preview.error) {
        this.setProperties({ spendError: preview.error, spendPreview: null });
      } else {
        this.setProperties({
          spendError: null,
          spendPreview: preview,
          spendPreviewAmount: amount
        });
      }
    },

    async confirmSpend(skillKey, amount) {
      let result = await this.api.requestOne('soulXpSpend', {
        skill_key: skillKey,
        amount,
        confirmed: 'true'
      });
      if (result.error) {
        this.set('spendError', result.error);
      } else {
        await this.loadXp();
        this.setProperties({
          spendError: null,
          spendPreview: null,
          spendPreviewAmount: null
        });
      }
    }
  }
});

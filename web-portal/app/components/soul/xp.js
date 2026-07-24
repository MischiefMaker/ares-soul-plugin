import Component from '@ember/component';
import { inject as service } from '@ember/service';

export default Component.extend({
  tagName: '',
  api: service('game-api'),
  isLoading: false,
  selectedTraitType: 'skill',

  didReceiveAttrs() {
    this._super(...arguments);
    if (this.isSelf) {
      this.loadXp();
    } else {
      this.setProperties({
        xp: null,
        skills: [],
        aspects: [],
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

      let aspects = (sheet.aspects || []).map((aspect) => ({
        key: aspect.key,
        name: aspect.name,
        rating: aspect.rating
      }));

      this.setProperties({ xp, skills, aspects });
    } finally {
      this.set('isLoading', false);
    }
  },

  actions: {
    selectTraitType(traitType) {
      this.setProperties({
        selectedTraitType: traitType,
        selectedTrait: null,
        spendError: null,
        spendPreview: null
      });
    },

    async previewSpend(traitType, traitKey, amount) {
      let preview = await this.api.requestOne('soulXpSpend', {
        trait_type: traitType,
        trait_key: traitKey,
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

    async confirmSpend(traitType, traitKey, amount) {
      let result = await this.api.requestOne('soulXpSpend', {
        trait_type: traitType,
        trait_key: traitKey,
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

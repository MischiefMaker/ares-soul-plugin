import Component from '@ember/component';
import { inject as service } from '@ember/service';

// "aspect:mind" -> "Aspect: Mind" (2026-07-31 live testing: "I would like
// things to be capitalized... and a space after the colon").
function formatXpSource(source) {
  if (!source) {
    return '';
  }
  return source
    .split(':')
    .map((part) => {
      let trimmed = part.trim();
      return trimmed.charAt(0).toUpperCase() + trimmed.slice(1);
    })
    .join(': ');
}

const XP_DIRECTION_LABELS = {
  award: 'Awarded',
  spend: 'Spent',
  correction: 'Corrected',
  reversal: 'Reversed'
};

function formatXpDirection(direction) {
  return XP_DIRECTION_LABELS[direction] || direction;
}

export default Component.extend({
  tagName: '',
  api: service('game-api'),
  isLoading: false,
  selectedTraitType: 'skill',

  init() {
    this._super(...arguments);
    this.setProperties({
      skills: [],
      aspects: []
    });
  },

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
        this.api.requestOne('soulXp', {}, null),
        this.api.requestOne('soulSheet', { character: this.character }, null)
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

      let history = (xp.history || []).map((entry) => ({
        ...entry,
        directionLabel: formatXpDirection(entry.direction),
        sourceLabel: formatXpSource(entry.source)
      }));

      this.setProperties({ xp: { ...xp, history }, skills, aspects });
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

    selectTrait(traitKey) {
      this.set('selectedTrait', traitKey || null);
    },

    async previewSpend(traitType, traitKey) {
      let preview = await this.api.requestOne('soulXpSpend', {
        trait_type: traitType,
        trait_key: traitKey,
        amount: 1
      }, null);
      if (preview.error) {
        this.setProperties({ spendError: preview.error, spendPreview: null });
      } else {
        this.setProperties({
          spendError: null,
          spendPreview: preview,
          spendPreviewAmount: 1
        });
      }
    },

    async confirmSpend(traitType, traitKey, amount) {
      let result = await this.api.requestOne('soulXpSpend', {
        trait_type: traitType,
        trait_key: traitKey,
        amount,
        confirmed: 'true'
      }, null);
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

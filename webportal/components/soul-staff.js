import Component from '@ember/component';
import { inject as service } from '@ember/service';

export default Component.extend({
  tagName: '',
  api: service('game-api'),
  isLoading: false,

  didReceiveAttrs() {
    this._super(...arguments);
    this.loadAudit();
    this.loadCatalogue();
  },

  async loadCatalogue() {
    let result = await this.api.requestOne('soulBnbCatalogue', { per_page: 1000 }, null);
    if (!result.error) {
      this.setProperties({ catalogueEntries: result.entries, availableSkills: result.available_skills });
    }
  },

  async call(cmd, args, resultProperty, successMessage) {
    this.set('isLoading', true);
    try {
      let result = await this.api.requestOne(cmd, args || {}, null);
      this.setProperties({
        error: result.error || null,
        successMessage: result.error
          ? null
          : (typeof successMessage === 'function'
              ? successMessage(result)
              : successMessage)
      });
      if (resultProperty) {
        this.set(resultProperty, result);
      }
      return result;
    } finally {
      this.set('isLoading', false);
    }
  },

  async loadAudit() {
    let result = await this.api.requestOne('soulAudit', { character: this.character }, null);
    if (!result.error) {
      this.set('auditResult', result);
    }
  },

  async mutate(cmd, args, successMessage) {
    let result = await this.call(cmd, args, 'actionResult', successMessage);
    if (!result.error) {
      await this.loadAudit();
    }
    return result;
  },

  actions: {
    correctFramework(kind) {
      return this.mutate('soulFrameworkCorrect', {
        character: this.character, kind: kind,
        key: this.frameworkKey, rating: this.frameworkRating, reason: this.frameworkReason
      }, (result) =>
        `${kind} ${result.key} changed from ${result.old_rating} to ${result.new_rating}.`
      );
    },
    correctResonance() {
      return this.mutate('soulResonance', {
        character: this.character, value: this.resonanceValue, reason: this.resonanceReason
      }, (result) =>
        `Resonance changed from ${result.old_value} to ${result.new_value}.`
      );
    },
    xpAward(catchup) {
      return this.mutate('soulXpAward', {
        character: this.character, amount: this.xpAmount, reason: this.xpReason,
        apply_catchup: catchup
      }, (result) =>
        `Awarded ${result.awarded} XP` +
          `${result.catchup_portion ? ` (${result.catchup_portion} catch-up)` : ''}.`
      );
    },
    xpCorrect(direction) {
      return this.mutate('soulXpCorrect', {
        character: this.character, amount: this.xpAmount, reason: this.xpReason,
        direction: direction
      }, (result) =>
        `${direction === 'reversal' ? 'Reversed' : 'Corrected'} available XP from ` +
          `${result.old_available} to ${result.new_available}.`
      );
    },
    selectBnbCatalogue(entry) {
      this.setProperties({ bnbCatalogueEntry: entry, bnbSkills: [] });
    },
    selectBnbSkills(skills) {
      this.set('bnbSkills', skills);
    },
    bnbGrant() {
      if (!this.bnbCatalogueEntry) {
        return;
      }
      let skills = (this.bnbSkills || []).map((skill) => skill.key);
      return this.mutate('soulBnbGrant', {
        character: this.character, catalogue_ref: this.bnbCatalogueEntry.id,
        level_state: this.bnbLevel || 'minor', explanation: this.bnbExplanation,
        associated_skills: skills
      }, (result) => `Granted ${result.entry.name}.`);
    },
    bnbTransition(cmd) {
      let args = { entry_id: this.bnbEntryId, level_state: this.bnbLevel, reason: this.bnbReason };
      if (cmd === 'soulBnbDelete') {
        args.confirmations =
          (this.deleteConfirmOne ? 1 : 0) + (this.deleteConfirmTwo ? 1 : 0);
      }
      let labels = {
        soulBnbProgress: 'progressed',
        soulBnbResolve: 'resolved or negated',
        soulBnbRestore: 'restored',
        soulBnbDelete: 'permanently deleted'
      };
      return this.mutate(
        cmd,
        args,
        `Boon/Bane entry #${this.bnbEntryId} ${labels[cmd]}.`
      );
    },
    culmination(cmd) {
      let labels = {
        soulCulminationPropose: 'proposed',
        soulCulminationApprove: 'approved',
        soulCulminationDeny: 'denied',
        soulCulminationRevoke: 'revoked',
        soulCulminationCorrect: 'corrected'
      };
      return this.mutate(cmd, {
        id: this.culminationId, character: this.character,
        title: this.culminationTitle, description: this.culminationDescription,
        reason: this.culminationReason
      }, `Culmination ${labels[cmd]}.`);
    }
  }
});

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
    this.loadFramework();
    this.loadBnbEntries();
    this.loadCulminations();
  },

  async loadCatalogue() {
    let result = await this.api.requestOne('soulBnbCatalogue', { per_page: 1000 }, null);
    if (!result.error) {
      this.setProperties({ catalogueEntries: result.entries, availableSkills: result.available_skills });
    }
  },

  async loadBnbEntries() {
    let result = await this.api.requestOne('soulBnbList', { character: this.character }, null);
    if (!result.error) {
      this.set('characterBnbEntries', result.entries);
    }
  },

  async loadCulminations() {
    let result = await this.api.requestOne('soulCulminations', { character: this.character }, null);
    if (!result.error) {
      this.set('culminations', result.entries);
    }
  },

  async loadFramework() {
    let result = await this.api.requestOne('soulFramework', {}, null);
    if (!result.error) {
      let aspects = (result.aspects || []).map((aspect) => ({ key: aspect.key, name: aspect.name, kind: 'aspect' }));
      let skills = (result.skills || []).map((skill) => ({ key: skill.key, name: skill.name, kind: 'skill' }));
      this.set('frameworkOptions', [...aspects, ...skills]);
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
    selectFrameworkEntry(entry) {
      this.set('frameworkEntry', entry);
    },
    correctFramework() {
      if (!this.frameworkEntry) {
        return;
      }
      let kind = this.frameworkEntry.kind;
      return this.mutate('soulFrameworkCorrect', {
        character: this.character, kind: kind,
        key: this.frameworkEntry.key, rating: this.frameworkRating, reason: this.frameworkReason
      }, (result) =>
        `${kind} ${result.key} changed from ${result.old_rating} to ${result.new_rating}.`
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
    async bnbGrant() {
      if (!this.bnbCatalogueEntry) {
        return;
      }
      let skills = (this.bnbSkills || []).map((skill) => skill.key);
      let result = await this.mutate('soulBnbGrant', {
        character: this.character, catalogue_ref: this.bnbCatalogueEntry.id,
        level_state: this.bnbLevel || 'minor', explanation: this.bnbExplanation,
        associated_skills: skills
      }, (granted) => `Granted ${granted.entry.name}.`);
      if (!result.error) {
        await this.loadBnbEntries();
      }
    },
    selectBnbEntry(entry) {
      this.setProperties({ bnbEntry: entry, bnbEntrySkills: [] });
    },
    selectBnbEntrySkills(skills) {
      this.set('bnbEntrySkills', skills);
    },
    // Changes the Skill(s) an already-granted entry affects, rather than
    // only being settable once at grant time (2026-07-26 live testing:
    // "Managing a player's boons and banes should also have a way of
    // changing/removing/adding a skill").
    async bnbSetEntrySkills() {
      if (!this.bnbEntry || !(this.bnbEntrySkills || []).length) {
        return;
      }
      let skills = this.bnbEntrySkills.map((skill) => skill.key);
      let result = await this.mutate('soulBnbSetEntrySkills', {
        entry_id: this.bnbEntry.id, skill_associations: skills
      }, (updated) => `${updated.entry.name}'s associated Skills updated.`);
      if (!result.error) {
        this.set('bnbEntry', null);
        await this.loadBnbEntries();
      }
    },
    async bnbAdjustLevel(direction) {
      if (!this.bnbEntry) {
        return;
      }
      let result = await this.mutate('soulBnbAdjustLevel', {
        entry_id: this.bnbEntry.id, direction: direction, explanation: this.bnbReason
      }, (adjusted) =>
        `${adjusted.entry.name} ${direction === 'regress' ? 'regressed' : 'progressed'} ` +
          `to ${adjusted.entry.level_state}.`
      );
      if (!result.error) {
        // Clear rather than leave the stale pre-update object selected -
        // the refreshed list has the new level_state, but this.bnbEntry
        // would otherwise keep pointing at the old one.
        this.set('bnbEntry', null);
        await this.loadBnbEntries();
      }
    },
    async bnbTransition(cmd) {
      if (!this.bnbEntry) {
        return;
      }
      let args = { entry_id: this.bnbEntry.id, reason: this.bnbReason };
      if (cmd === 'soulBnbDelete') {
        args.confirmations =
          (this.deleteConfirmOne ? 1 : 0) + (this.deleteConfirmTwo ? 1 : 0);
      }
      let labels = {
        soulBnbResolve: 'resolved or negated',
        soulBnbRestore: 'restored',
        soulBnbDelete: 'permanently deleted'
      };
      let result = await this.mutate(
        cmd,
        args,
        `Boon/Bane entry #${this.bnbEntry.id} ${labels[cmd]}.`
      );
      if (!result.error) {
        this.set('bnbEntry', null);
        await this.loadBnbEntries();
      }
    },
    async culminationPropose() {
      let result = await this.mutate('soulCulminationPropose', {
        character: this.character, title: this.culminationTitle, description: this.culminationDescription
      }, (proposed) => `Culmination "${proposed.culmination.title}" proposed.`);
      if (!result.error) {
        await this.loadCulminations();
      }
    },
    selectCulminationEntry(entry) {
      this.set('culminationEntry', entry);
    },
    async culminationManage(cmd) {
      if (!this.culminationEntry) {
        return;
      }
      let labels = {
        soulCulminationApprove: 'approved',
        soulCulminationDeny: 'denied',
        soulCulminationRevoke: 'revoked',
        soulCulminationCorrect: 'corrected'
      };
      let result = await this.mutate(cmd, {
        id: this.culminationEntry.id, title: this.culminationCorrectTitle,
        description: this.culminationCorrectDescription, reason: this.culminationReason
      }, `Culmination ${labels[cmd]}.`);
      if (!result.error) {
        await this.loadCulminations();
      }
    }
  }
});

import Component from '@ember/component';
import { inject as service } from '@ember/service';

export default Component.extend({
  tagName: '',
  api: service('game-api'),
  isLoading: false,

  async call(cmd, args, resultProperty, successMessage) {
    this.set('isLoading', true);
    try {
      let result = await this.api.requestOne(cmd, args || {});
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

  async refreshAuditIfVisible() {
    if (!this.auditResult || !this.auditCharacter) {
      return;
    }
    let result = await this.api.requestOne('soulAudit', {
      character: this.auditCharacter
    });
    if (!result.error) {
      this.set('auditResult', result);
    }
  },

  async mutate(cmd, args, successMessage) {
    let result = await this.call(cmd, args, 'actionResult', successMessage);
    if (!result.error) {
      await this.refreshAuditIfVisible();
    }
    return result;
  },

  actions: {
    loadFramework() {
      return this.call('soulFramework', {}, 'framework', 'Framework loaded.');
    },
    correctFramework(kind) {
      return this.mutate('soulFrameworkCorrect', {
        character: this.frameworkCharacter, kind: kind,
        key: this.frameworkKey, rating: this.frameworkRating,
        reason: this.frameworkReason
      }, (result) =>
        `${kind} ${result.key} changed from ${result.old_rating} to ${result.new_rating}.`
      );
    },
    reloadConfig() {
      return this.call(
        'soulReload',
        {},
        'reloadResult',
        (result) => result.success
          ? 'SOUL configuration is valid and read live.'
          : 'SOUL configuration validation completed with errors.'
      );
    },
    loadAudit() {
      return this.call(
        'soulAudit',
        { character: this.auditCharacter },
        'auditResult',
        `Audit loaded for ${this.auditCharacter}.`
      );
    },
    correctResonance() {
      return this.mutate('soulResonance', {
        character: this.resonanceCharacter, value: this.resonanceValue, reason: this.resonanceReason
      }, (result) =>
        `${this.resonanceCharacter}'s Resonance changed from ${result.old_value} to ${result.new_value}.`
      );
    },
    xpAward(catchup) {
      return this.mutate('soulXpAward', {
        character: this.xpCharacter, amount: this.xpAmount, reason: this.xpReason,
        apply_catchup: catchup
      }, (result) =>
        `Awarded ${result.awarded} XP to ${this.xpCharacter}` +
          `${result.catchup_portion ? ` (${result.catchup_portion} catch-up)` : ''}.`
      );
    },
    xpScene(catchup) {
      return this.mutate('soulXpScene', {
        scene_id: this.xpSceneId, amount: this.xpAmount, reason: this.xpReason,
        apply_catchup: catchup, confirmed: this.scenePreview ? 'true' : 'false'
      }, (result) => result.preview
        ? `Scene XP preview loaded for ${(result.recipients || []).length} recipients.`
        : `Scene XP award completed for scene #${this.xpSceneId}.`
      ).then((result) => {
        if (!result.error) {
          this.set('scenePreview', result.preview ? result : null);
        }
        return result;
      });
    },
    xpCorrect(direction) {
      return this.mutate('soulXpCorrect', {
        character: this.xpCharacter, amount: this.xpAmount, reason: this.xpReason,
        direction: direction
      }, (result) =>
        `${direction === 'reversal' ? 'Reversed' : 'Corrected'} ${this.xpCharacter}'s available XP from ` +
          `${result.old_available} to ${result.new_available}.`
      );
    },
    bnbCreate() {
      return this.mutate('soulBnbCreate', {
        name: this.bnbName, tag: this.bnbTag, kind: this.bnbKind,
        description: this.bnbDescription, chargen_available: this.bnbChargen,
        modifier_eligible: this.bnbModifierEligible
      }, (result) => `Created catalogue entry #${result.entry.id} ${result.entry.name}.`);
    },
    bnbGrant() {
      return this.mutate('soulBnbGrant', {
        character: this.bnbCharacter, catalogue_ref: this.bnbReference,
        level_state: this.bnbLevel, explanation: this.bnbExplanation
      }, (result) => `Granted ${result.entry.name} to ${this.bnbCharacter}.`);
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
        id: this.culminationId, character: this.culminationCharacter,
        title: this.culminationTitle, description: this.culminationDescription,
        reason: this.culminationReason
      }, `Culmination ${labels[cmd]}.`);
    }
  }
});

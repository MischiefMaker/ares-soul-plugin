import Component from '@ember/component';
import { inject as service } from '@ember/service';

export default Component.extend({
  tagName: '',
  api: service('game-api'),
  isLoading: false,

  async call(cmd, args, resultProperty) {
    this.set('isLoading', true);
    try {
      let result = await this.api.requestOne(cmd, args || {});
      if (!result.error && resultProperty) {
        this.set(resultProperty, result);
      }
      return result;
    } finally {
      this.set('isLoading', false);
    }
  },

  actions: {
    loadFramework() { return this.call('soulFramework', {}, 'framework'); },
    reloadConfig() { return this.call('soulReload', {}, 'reloadResult'); },
    loadAudit() { return this.call('soulAudit', { character: this.auditCharacter }, 'auditResult'); },
    correctResonance() {
      return this.call('soulResonance', {
        character: this.resonanceCharacter, value: this.resonanceValue, reason: this.resonanceReason
      }, 'actionResult');
    },
    xpAward(catchup) {
      return this.call('soulXpAward', {
        character: this.xpCharacter, amount: this.xpAmount, reason: this.xpReason,
        apply_catchup: catchup
      }, 'actionResult');
    },
    xpScene(catchup) {
      return this.call('soulXpScene', {
        scene_id: this.xpSceneId, amount: this.xpAmount, reason: this.xpReason,
        apply_catchup: catchup, confirmed: this.scenePreview ? 'true' : 'false'
      }, 'scenePreview');
    },
    xpCorrect() {
      return this.call('soulXpCorrect', {
        character: this.xpCharacter, amount: this.xpAmount, reason: this.xpReason
      }, 'actionResult');
    },
    bnbCreate() {
      return this.call('soulBnbCreate', {
        name: this.bnbName, tag: this.bnbTag, kind: this.bnbKind,
        description: this.bnbDescription, chargen_available: this.bnbChargen,
        modifier_eligible: this.bnbModifierEligible
      }, 'actionResult');
    },
    bnbGrant() {
      return this.call('soulBnbGrant', {
        character: this.bnbCharacter, catalogue_ref: this.bnbReference,
        level_state: this.bnbLevel, explanation: this.bnbExplanation
      }, 'actionResult');
    },
    bnbTransition(cmd) {
      let args = { entry_id: this.bnbEntryId, level_state: this.bnbLevel, reason: this.bnbReason };
      if (cmd === 'soulBnbDelete') {
        args.confirmations =
          (this.deleteConfirmOne ? 1 : 0) + (this.deleteConfirmTwo ? 1 : 0);
      }
      return this.call(cmd, args, 'actionResult');
    },
    culmination(cmd) {
      return this.call(cmd, {
        id: this.culminationId, character: this.culminationCharacter,
        title: this.culminationTitle, description: this.culminationDescription,
        reason: this.culminationReason
      }, 'actionResult');
    }
  }
});

// Admin "SOUL management" page controller. Automatically installed to
// ares-webportal/app/controllers/ via plugin/install. Pairs with
// webportal/routes/admin-soul.js and webportal/templates/admin-soul.hbs.
//
// Everything here is global/catalogue-scoped, not tied to one character -
// per-character staff actions (XP award, Resonance correction, B&B grant,
// Culminations, audit) live on the profile tab instead (soul-staff.js),
// scoped to whichever character's profile is open. model.requests is the
// pending Boon/Bane request queue (see the route) - reload() re-fetches it
// after every approve/deny so the list never shows a stale, already-
// resolved request.
import Controller from '@ember/controller';
import { inject as service } from '@ember/service';

export default Controller.extend({
  gameApi: service(),
  isLoading: false,

  async call(cmd, args, resultProperty, successMessage) {
    this.set('isLoading', true);
    try {
      let result = await this.gameApi.requestOne(cmd, args || {}, null);
      this.setProperties({
        error: result.error || null,
        successMessage: result.error
          ? null
          : (typeof successMessage === 'function' ? successMessage(result) : successMessage)
      });
      if (resultProperty) {
        this.set(resultProperty, result);
      }
      return result;
    } finally {
      this.set('isLoading', false);
    }
  },

  async reloadRequests() {
    let result = await this.gameApi.requestOne('soulBnbRequestsList', { status: 'pending' }, null);
    if (!result.error) {
      this.set('model.requests', result.requests);
    }
  },

  actions: {
    async approveRequest(id) {
      let result = await this.call('soulBnbRequestApprove', { request_id: id }, null, 'Request approved.');
      if (!result.error) {
        await this.reloadRequests();
      }
    },
    async denyRequest(id) {
      let result = await this.call(
        'soulBnbRequestDeny', { request_id: id, reason: this.denyReason }, null, 'Request denied.'
      );
      if (!result.error) {
        this.set('denyReason', '');
        await this.reloadRequests();
      }
    },
    loadFramework() {
      return this.call('soulFramework', {}, 'framework', 'Framework loaded.');
    },
    reloadConfig() {
      return this.call(
        'soulReload', {}, 'reloadResult',
        (result) => result.success
          ? 'SOUL configuration is valid and read live.'
          : 'SOUL configuration validation completed with errors.'
      );
    },
    bnbCreate() {
      let skillAssociations = (this.bnbSkillAssociations || '')
        .split(',').map((key) => key.trim()).filter((key) => key.length);
      return this.call('soulBnbCreate', {
        name: this.bnbName, tag: this.bnbTag, kind: this.bnbKind,
        description: this.bnbDescription, chargen_available: this.bnbChargen,
        modifier_eligible: this.bnbModifierEligible, skill_associations: skillAssociations
      }, null, (result) => `Created catalogue entry #${result.entry.id} ${result.entry.name}.`);
    },
    bnbSetSkills() {
      let skillAssociations = (this.bnbSkillsValue || '')
        .split(',').map((key) => key.trim()).filter((key) => key.length);
      return this.call('soulBnbSetSkills', {
        id_or_tag: this.bnbSkillsReference, skill_associations: skillAssociations
      }, null, (result) => `Associated Skills for ${result.entry.name} updated.`);
    },
    xpScene(catchup) {
      return this.call('soulXpScene', {
        scene_id: this.xpSceneId, amount: this.xpAmount, reason: this.xpReason,
        apply_catchup: catchup, confirmed: this.scenePreview ? 'true' : 'false'
      }, null, (result) => result.preview
        ? `Scene XP preview loaded for ${(result.recipients || []).length} recipients.`
        : `Scene XP award completed for scene #${this.xpSceneId}.`
      ).then((result) => {
        if (!result.error) {
          this.set('scenePreview', result.preview ? result : null);
        }
        return result;
      });
    }
  }
});

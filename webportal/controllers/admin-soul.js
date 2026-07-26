// Admin "SOUL management" page controller. Automatically installed to
// ares-webportal/app/controllers/ via plugin/install. Pairs with
// webportal/routes/admin-soul.js and webportal/templates/admin-soul.hbs.
//
// Most of this is global/catalogue-scoped, not tied to one already-open
// profile - Culminations and audit stay on the profile tab only
// (soul-staff.js), scoped to whichever character's profile is open.
// Resonance correction, XP award/correction, and per-character B&B
// management (grant/progress/regress/resolve/restore/delete) exist in
// both places: here via a character-picker dropdown (model.characters,
// see the route) for staff not currently on that player's profile - moved
// here from the profile panel entirely (2026-07-25: rarely needed enough
// that it didn't belong cluttering every profile visit); there implicitly
// scoped to the open profile. model.requests is the pending Boon/Bane
// request queue (see the route) - reload() re-fetches it after every
// approve/deny so the list never shows a stale, already-resolved request.
import Controller from '@ember/controller';
import { inject as service } from '@ember/service';

export default Controller.extend({
  gameApi: service(),
  isLoading: false,
  // Tabbed layout (2026-07-26 live testing: "let's use tabs on the admin
  // page to make it cleaner. Pending requests as the top default tab,
  // then XP, then BNBs, Skills, Resonance") - plain conditional
  // rendering rather than Bootstrap's data-bs-toggle="tab" JS behavior,
  // since nothing in this codebase initializes Bootstrap's JS bundle
  // (see soul-culmination.js's own tooltip-vs-button lesson).
  activeTab: 'requests',

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

  async loadBnbEntriesForPlayer() {
    if (!this.bnbPlayer) {
      this.set('characterBnbEntries', []);
      return;
    }
    let result = await this.gameApi.requestOne('soulBnbList', { character: this.bnbPlayer.name }, null);
    if (!result.error) {
      this.set('characterBnbEntries', result.entries);
    }
  },

  actions: {
    selectTab(tab) {
      this.set('activeTab', tab);
    },
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
    // model.catalogue.entries is already the whole active catalogue (the
    // route loads it with per_page: 1000) - bucket it client-side rather
    // than making a second request (2026-07-26 live testing: "add a
    // button/link to also view the full catalogue, organized the same"
    // as the profile's Boons/Banes expando picker).
    toggleCatalogueBrowser() {
      if (!this.catalogueBrowserOpen) {
        let entries = (this.model.catalogue && this.model.catalogue.entries) || [];
        this.setProperties({
          catalogueBoons: entries.filter((entry) => (entry.kind || '').toLowerCase() === 'boon'),
          catalogueBanes: entries.filter((entry) => (entry.kind || '').toLowerCase() === 'bane')
        });
      }
      this.toggleProperty('catalogueBrowserOpen');
    },
    reloadConfig() {
      return this.call(
        'soulReload', {}, 'reloadResult',
        (result) => result.success
          ? 'SOUL configuration is valid and read live.'
          : 'SOUL configuration validation completed with errors.'
      );
    },
    selectBnbCreateSkills(skills) {
      this.set('bnbSkillAssociations', skills);
    },
    bnbCreate() {
      let skillAssociations = (this.bnbSkillAssociations || []).map((skill) => skill.key);
      return this.call('soulBnbCreate', {
        name: this.bnbName, tag: this.bnbTag, kind: this.bnbKind,
        description: this.bnbDescription, chargen_available: this.bnbChargen,
        modifier_eligible: this.bnbModifierEligible, skill_associations: skillAssociations
      }, null, (result) => `Created catalogue entry #${result.entry.id} ${result.entry.name}.`);
    },
    selectBnbSkillsEntry(entry) {
      this.set('bnbSkillsEntry', entry);
    },
    selectBnbSkillsValue(skills) {
      this.set('bnbSkillsValue', skills);
    },
    bnbSetSkills() {
      if (!this.bnbSkillsEntry) {
        return;
      }
      let skillAssociations = (this.bnbSkillsValue || []).map((skill) => skill.key);
      return this.call('soulBnbSetSkills', {
        id_or_tag: this.bnbSkillsEntry.id, skill_associations: skillAssociations
      }, null, (result) => `Associated Skills for ${result.entry.name} updated.`);
    },
    selectResonancePlayer(player) {
      this.set('resonancePlayer', player);
    },
    selectResonanceValue(value) {
      this.set('resonanceValue', value);
    },
    correctResonance() {
      if (!this.resonancePlayer || this.resonanceValue === undefined || this.resonanceValue === null) {
        return;
      }
      return this.call('soulResonance', {
        character: this.resonancePlayer.name, value: this.resonanceValue, reason: this.resonanceReason
      }, null, (result) =>
        `${this.resonancePlayer.name}'s Resonance changed from ` +
          `${result.old_value === null ? 'Unset' : `R${result.old_value}`} to R${result.new_value}.`
      );
    },
    // Reverse lookup - which characters hold a given catalogue entry
    // (2026-07-26 live testing: "let's add to the admin page a way to
    // search for players with specific bnbs").
    selectBnbSearchEntry(entry) {
      this.setProperties({ bnbSearchEntry: entry, bnbSearchResults: null });
    },
    bnbSearchByEntry() {
      if (!this.bnbSearchEntry) {
        return;
      }
      return this.call('soulBnbCharactersWithEntry', {
        catalogue_ref: this.bnbSearchEntry.id
      }, 'bnbSearchResults', (result) =>
        `${result.entries.length} character(s) found with ${this.bnbSearchEntry.name}.`
      );
    },
    selectBnbPlayer(player) {
      this.setProperties({ bnbPlayer: player, bnbEntry: null, characterBnbEntries: [] });
      return this.loadBnbEntriesForPlayer();
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
      let result = await this.call('soulBnbSetEntrySkills', {
        entry_id: this.bnbEntry.id, skill_associations: skills
      }, null, (result) => `${result.entry.name}'s associated Skills updated.`);
      if (!result.error) {
        this.set('bnbEntry', null);
        await this.loadBnbEntriesForPlayer();
      }
    },
    selectBnbGrantCatalogue(entry) {
      this.setProperties({ bnbCatalogueEntry: entry, bnbSkills: [] });
    },
    selectBnbGrantSkills(skills) {
      this.set('bnbSkills', skills);
    },
    async bnbGrant() {
      if (!this.bnbPlayer || !this.bnbCatalogueEntry) {
        return;
      }
      let skills = (this.bnbSkills || []).map((skill) => skill.key);
      let result = await this.call('soulBnbGrant', {
        character: this.bnbPlayer.name, catalogue_ref: this.bnbCatalogueEntry.id,
        level_state: this.bnbLevel || 'minor', explanation: this.bnbExplanation,
        associated_skills: skills
      }, null, (result) => `Granted ${result.entry.name} to ${this.bnbPlayer.name}.`);
      if (!result.error) {
        await this.loadBnbEntriesForPlayer();
      }
    },
    async bnbAdjustLevel(direction) {
      if (!this.bnbEntry) {
        return;
      }
      let result = await this.call('soulBnbAdjustLevel', {
        entry_id: this.bnbEntry.id, direction: direction, explanation: this.bnbReason
      }, null, (adjusted) =>
        `${adjusted.entry.name} ${direction === 'regress' ? 'regressed' : 'progressed'} ` +
          `to ${adjusted.entry.level_state}.`
      );
      if (!result.error) {
        // Clear rather than leave the stale pre-update object selected -
        // the refreshed list has the new level_state.
        this.set('bnbEntry', null);
        await this.loadBnbEntriesForPlayer();
      }
    },
    async bnbTransition(cmd) {
      if (!this.bnbEntry) {
        return;
      }
      let args = { entry_id: this.bnbEntry.id, reason: this.bnbReason };
      if (cmd === 'soulBnbDelete') {
        args.confirmations = (this.deleteConfirmOne ? 1 : 0) + (this.deleteConfirmTwo ? 1 : 0);
      }
      let labels = {
        soulBnbResolve: 'resolved or negated',
        soulBnbRestore: 'restored',
        soulBnbDelete: 'permanently deleted'
      };
      let result = await this.call(
        cmd, args, null, `Boon/Bane entry #${this.bnbEntry.id} ${labels[cmd]}.`
      );
      if (!result.error) {
        this.set('bnbEntry', null);
        await this.loadBnbEntriesForPlayer();
      }
    },
    selectXpScene(scene) {
      this.set('xpScene', scene);
    },
    xpScene(catchup) {
      if (!this.xpScene) {
        return;
      }
      return this.call('soulXpScene', {
        scene_id: this.xpScene.id, amount: this.xpAmount, reason: this.xpReason,
        apply_catchup: catchup, confirmed: this.scenePreview ? 'true' : 'false'
      }, null, (result) => result.preview
        ? `Scene XP preview loaded for ${(result.recipients || []).length} recipients.`
        : `Scene XP award completed for scene #${this.xpScene.id}.`
      ).then((result) => {
        if (!result.error) {
          this.set('scenePreview', result.preview ? result : null);
        }
        return result;
      });
    },
    selectXpPlayer(char) {
      this.set('xpPlayer', char);
    },
    xpAwardPlayer(catchup) {
      if (!this.xpPlayer) {
        return;
      }
      return this.call('soulXpAward', {
        character: this.xpPlayer.name, amount: this.xpPlayerAmount, reason: this.xpPlayerReason,
        apply_catchup: catchup
      }, null, (result) =>
        `Awarded ${result.awarded} XP to ${this.xpPlayer.name}` +
          `${result.catchup_portion ? ` (${result.catchup_portion} catch-up)` : ''}.`
      );
    },
    xpCorrectPlayer(direction) {
      if (!this.xpPlayer) {
        return;
      }
      return this.call('soulXpCorrect', {
        character: this.xpPlayer.name, amount: this.xpPlayerAmount, reason: this.xpPlayerReason,
        direction: direction
      }, null, (result) =>
        `${direction === 'reversal' ? 'Reversed' : 'Corrected'} ${this.xpPlayer.name}'s available XP from ` +
          `${result.old_available} to ${result.new_available}.`
      );
    }
  }
});

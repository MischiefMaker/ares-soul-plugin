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
import { set } from '@ember/object';
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

  async reloadOpenRolls() {
    let result = await this.gameApi.requestOne('soulRollOpenForReview', {}, null);
    if (!result.error) {
      this.set('model.openRolls', result.pending_rolls || []);
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
      // model.resonanceConfig already carries the full Aspect/Skill lists
      // (fetched eagerly for the Resonance dropdown) - reuse it for the
      // Skills tab's correction picker instead of a second request.
      // Computed once, lazily, on first visit to the tab (2026-07-26 live
      // testing: "Skills tab -- we should be able to modify a character's
      // skills and aspects here too").
      if (tab === 'skills' && !this.skillsFrameworkOptions) {
        let config = this.model.resonanceConfig || {};
        let aspects = (config.aspects || [])
          .map((aspect) => ({ key: aspect.key, name: aspect.name, kind: 'aspect' }));
        let skills = (config.skills || [])
          .map((skill) => ({ key: skill.key, name: skill.name, kind: 'skill' }));
        this.set('skillsFrameworkOptions', [...aspects, ...skills]);
      }
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
    // Do the GM part of an open roll straight from the admin page (2026-07-26
    // live testing: "The GM rolls list on the admin page should allow the
    // admin to do the GM part of the roll") - marks each system-suggested
    // Boon/Bane candidate mandatory/optional, same soulRollReview/
    // soulRollMark pair the scene roll widget's own GM Review panel uses.
    // can_review_pending? (SoulRollApi) always allows manage_soul staff
    // regardless of scene participation, so this works for any open roll
    // site-wide, matching the list itself.
    async selectGmRoll(pending) {
      this.set('gmReviewIsLoading', true);
      try {
        let response = await this.gameApi.requestOne(
          'soulRollReview', { pending_roll_id: pending.id }, null
        );
        if (!response.error) {
          let candidates = (response.candidates || []).map((candidate) =>
            Object.assign({}, candidate, { mandatory: false, optional: false })
          );
          this.setProperties({ gmReviewRoll: pending, gmCandidates: candidates });
        }
      } finally {
        this.set('gmReviewIsLoading', false);
      }
    },
    backToOpenRolls() {
      this.setProperties({ gmReviewRoll: null, gmCandidates: [] });
    },
    toggleGmMandatory(candidate, event) {
      set(candidate, 'mandatory', event.target.checked);
      if (event.target.checked) {
        set(candidate, 'optional', false);
      }
    },
    toggleGmOptional(candidate, event) {
      set(candidate, 'optional', event.target.checked);
      if (event.target.checked) {
        set(candidate, 'mandatory', false);
      }
    },
    async submitGmSelections() {
      if (!this.gmReviewRoll) {
        return;
      }
      let mandatoryTags = (this.gmCandidates || [])
        .filter((candidate) => candidate.mandatory)
        .map((candidate) => candidate.tag);
      let optionalTags = (this.gmCandidates || [])
        .filter((candidate) => candidate.optional)
        .map((candidate) => candidate.tag);

      let result = await this.call('soulRollMark', {
        pending_roll_id: this.gmReviewRoll.id,
        mandatory_tags: mandatoryTags, optional_tags: optionalTags
      }, null, 'SOUL roll selections submitted.');
      if (!result.error) {
        this.setProperties({ gmReviewRoll: null, gmCandidates: [] });
        await this.reloadOpenRolls();
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
    async bnbCreate() {
      let skillAssociations = (this.bnbSkillAssociations || []).map((skill) => skill.key);
      let result = await this.call('soulBnbCreate', {
        name: this.bnbName, tag: this.bnbTag, kind: this.bnbKind,
        description: this.bnbDescription, chargen_available: this.bnbChargen,
        modifier_eligible: this.bnbModifierEligible, skill_associations: skillAssociations
      }, null, (result) => `Created catalogue entry #${result.entry.id} ${result.entry.name}.`);
      if (!result.error) {
        this.setProperties({
          bnbName: '', bnbTag: '', bnbKind: '', bnbDescription: '', bnbSkillAssociations: []
        });
      }
    },
    selectBnbSkillsEntry(entry) {
      this.set('bnbSkillsEntry', entry);
    },
    selectBnbSkillsValue(skills) {
      this.set('bnbSkillsValue', skills);
    },
    async bnbSetSkills() {
      if (!this.bnbSkillsEntry) {
        return;
      }
      let skillAssociations = (this.bnbSkillsValue || []).map((skill) => skill.key);
      let result = await this.call('soulBnbSetSkills', {
        id_or_tag: this.bnbSkillsEntry.id, skill_associations: skillAssociations
      }, null, (result) => `Associated Skills for ${result.entry.name} updated.`);
      if (!result.error) {
        this.setProperties({ bnbSkillsEntry: null, bnbSkillsValue: [] });
      }
    },
    selectResonancePlayer(player) {
      this.set('resonancePlayer', player);
    },
    selectResonanceValue(value) {
      this.set('resonanceValue', value);
    },
    async correctResonance() {
      if (!this.resonancePlayer || this.resonanceValue === undefined || this.resonanceValue === null) {
        return;
      }
      let result = await this.call('soulResonance', {
        character: this.resonancePlayer.name, value: this.resonanceValue, reason: this.resonanceReason
      }, null, (result) =>
        `${this.resonancePlayer.name}'s Resonance changed from ` +
          `${result.old_value === null ? 'Unset' : `R${result.old_value}`} to R${result.new_value}.`
      );
      if (!result.error) {
        this.setProperties({ resonancePlayer: null, resonanceValue: null, resonanceReason: '' });
      }
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
        this.setProperties({ bnbEntry: null, bnbEntrySkills: [] });
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
        this.setProperties({
          bnbCatalogueEntry: null, bnbLevel: 'minor', bnbSkills: [], bnbExplanation: ''
        });
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
        // the refreshed list has the new level_state. Also clear the
        // reason text and delete-confirm checkboxes so they don't carry
        // over to whichever entry is picked next (2026-07-26 live
        // testing: "we generally need to reset the entry fields when
        // something is submitted").
        this.setProperties({
          bnbEntry: null, bnbReason: '', deleteConfirmOne: false, deleteConfirmTwo: false
        });
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
        this.setProperties({
          bnbEntry: null, bnbReason: '', deleteConfirmOne: false, deleteConfirmTwo: false
        });
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
          if (result.preview) {
            this.set('scenePreview', result);
          } else {
            // The real (confirmed) award went through - reset for the
            // next one instead of leaving stale amount/reason/scene
            // behind (2026-07-26 live testing: "we generally need to
            // reset the entry fields when something is submitted").
            this.setProperties({
              scenePreview: null, xpScene: null, xpAmount: '', xpReason: ''
            });
          }
        }
        return result;
      });
    },
    selectXpPlayer(char) {
      this.set('xpPlayer', char);
    },
    async xpAwardPlayer(catchup) {
      if (!this.xpPlayer) {
        return;
      }
      let result = await this.call('soulXpAward', {
        character: this.xpPlayer.name, amount: this.xpPlayerAmount, reason: this.xpPlayerReason,
        apply_catchup: catchup
      }, null, (result) =>
        `Awarded ${result.awarded} XP to ${this.xpPlayer.name}` +
          `${result.catchup_portion ? ` (${result.catchup_portion} catch-up)` : ''}.`
      );
      if (!result.error) {
        this.setProperties({ xpPlayerAmount: '', xpPlayerReason: '' });
      }
    },
    async xpCorrectPlayer(direction) {
      if (!this.xpPlayer) {
        return;
      }
      let result = await this.call('soulXpCorrect', {
        character: this.xpPlayer.name, amount: this.xpPlayerAmount, reason: this.xpPlayerReason,
        direction: direction
      }, null, (result) =>
        `${direction === 'reversal' ? 'Reversed' : 'Corrected'} ${this.xpPlayer.name}'s available XP from ` +
          `${result.old_available} to ${result.new_available}.`
      );
      if (!result.error) {
        this.setProperties({ xpPlayerAmount: '', xpPlayerReason: '' });
      }
    },
    // Adjust a specific player's Skill/Aspect rating (2026-07-26 live
    // testing: "Skills tab -- we should be able to modify a character's
    // skills and aspects here too") - mirrors soul-staff.js's own
    // correctFramework action, scoped by a player picker instead of the
    // implicit "whichever profile is open" context.
    selectSkillsPlayer(player) {
      this.setProperties({
        skillsPlayer: player, skillsFrameworkEntry: null, skillsRating: '', skillsReason: ''
      });
    },
    selectSkillsFrameworkEntry(entry) {
      this.set('skillsFrameworkEntry', entry);
    },
    async correctPlayerSkill() {
      if (!this.skillsPlayer || !this.skillsFrameworkEntry) {
        return;
      }
      let kind = this.skillsFrameworkEntry.kind;
      let result = await this.call('soulFrameworkCorrect', {
        character: this.skillsPlayer.name, kind: kind,
        key: this.skillsFrameworkEntry.key, rating: this.skillsRating, reason: this.skillsReason
      }, null, (result) =>
        `${this.skillsPlayer.name}'s ${kind} ${result.key} changed from ${result.old_rating} to ${result.new_rating}.`
      );
      if (!result.error) {
        this.setProperties({ skillsFrameworkEntry: null, skillsRating: '', skillsReason: '' });
      }
    }
  }
});

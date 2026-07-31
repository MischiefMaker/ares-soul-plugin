import Component from '@ember/component';
import { inject as service } from '@ember/service';

export default Component.extend({
  tagName: '',
  api: service('game-api'),
  isLoading: false,
  catalogueOpen: false,

  didInsertElement() {
    this._super(...arguments);
    this.refreshStatus();
  },

  // Runs chargen for whichever character this component was handed - see
  // chargen-custom.snippet.hbs. Staff visiting the game's own /chargen/:id
  // admin page (the SOUL tab) get @char set to the applicant being
  // reviewed; a player's own chargen page (which redirects to
  // /chargen/<their own id>) gets @char set to themselves either way. No
  // @char at all (an older installed snippet that hasn't been updated to
  // pass it) falls back to the server defaulting to the logged-in
  // character - the only thing this component could see before this fix.
  targetArgs(extra) {
    let args = Object.assign({}, extra || {});
    if (this.char && this.char.id) {
      args.character_id = this.char.id;
    }
    return args;
  },

  async refreshStatus() {
    let result = await this.api.requestOne('soulChargenStatus', this.targetArgs(), null);
    if (result.error) {
      this.setProperties({ status: null, error: result.error });
      return;
    }
    this.setProperties({ status: result, error: null });
  },

  async request(cmd, args) {
    this.set('isLoading', true);
    try {
      let result = await this.api.requestOne(cmd, this.targetArgs(args), null);
      if (result.error) {
        // Reload from the server so a rejected Skill/Resonance/B&B change
        // (e.g. over budget) doesn't leave a stale, never-actually-saved
        // value showing in a two-way-bound input - but keep the error
        // message visible, which a plain reload would otherwise clear.
        this.set('error', result.error);
        await this.refreshStatus();
      } else {
        this.setProperties({
          status: result, error: null, warning: result.warning || null,
          selectedCatalogue: null, explanation: null, bnbSkills: []
        });
      }
    } finally {
      this.set('isLoading', false);
    }
  },

  actions: {
    openCatalogue() {
      this.set('catalogueOpen', true);
    },
    closeCatalogue() {
      this.set('catalogueOpen', false);
    },
    setResonance(value) {
      return this.request('soulChargenResonance', { value });
    },
    setSkill(skill, event) {
      return this.request('soulChargenSkill', {
        skill_key: skill.key,
        rating: event.target.value
      });
    },
    adjustSkill(skill, delta) {
      // Only guard the true floor here - the starting cap is a soft,
      // Resonance-derived budget the server now warns about rather than
      // blocks, so a Skill left above a since-lowered cap can still be
      // adjusted (including back down) instead of getting stuck (mischief
      // bug list, 2026-07-25).
      let rating = Number(skill.rating || 0) + delta;
      if (rating < 0) {
        return;
      }
      return this.request('soulChargenSkill', {
        skill_key: skill.key,
        rating
      });
    },
    adjustAspect(aspect, delta) {
      let rating = Number(aspect.rating || 0) + delta;
      if (rating < Number(this.get('status.aspect_min_rating')) ||
          rating > Number(this.get('status.aspect_max_rating'))) {
        return;
      }
      return this.request('soulChargenAspect', {
        aspect_key: aspect.key,
        rating
      });
    },
    selectCatalogue(entry) {
      this.setProperties({ selectedCatalogue: entry, bnbSkills: [] });
    },
    selectBnbSkills(skills) {
      this.set('bnbSkills', skills);
    },
    addBnb() {
      if (!this.selectedCatalogue || !this.explanation) {
        return;
      }
      let skills = (this.bnbSkills || []).map((skill) => skill.key);
      return this.request('soulChargenBnb', {
        reference: this.selectedCatalogue.id,
        level_state: this.selectedLevel || 'minor',
        explanation: this.explanation,
        associated_skills: skills
      });
    },
    dropBnb(entry) {
      return this.request('soulChargenDrop', { entry_id: entry.id });
    }
  }
});

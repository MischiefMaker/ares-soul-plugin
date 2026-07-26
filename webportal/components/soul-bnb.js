import Component from '@ember/component';
import { inject as service } from '@ember/service';

export default Component.extend({
  tagName: '',
  api: service('game-api'),
  isLoading: false,
  catalogueLoading: false,
  isSubmitting: false,
  pickerOpen: false,
  detailOpen: false,

  didReceiveAttrs() {
    this._super(...arguments);
    this.loadList();
  },

  async loadList() {
    this.set('isLoading', true);
    try {
      let result = await this.api.requestOne('soulBnbList', { character: this.character }, null);
      this.setProperties({ entries: result.entries, requests: result.requests });
    } finally {
      this.set('isLoading', false);
    }
  },

  // Fetches the whole active catalogue (not paginated - split into a
  // Boons expando and a Banes expando instead, 2026-07-26 live testing:
  // "let's split them into Boons and Banes, and make each an expando
  // type") and buckets it client-side, mirroring the same per_page: 1000
  // "fetch everything" convention soul-staff.js/admin-soul.js/
  // soul-scene-tools.js already use for this same endpoint.
  async loadCatalogue() {
    this.set('catalogueLoading', true);
    try {
      let result = await this.api.requestOne('soulBnbCatalogue', {
        per_page: 1000, query: this.query
      }, null);
      let entries = result.entries || [];
      this.setProperties({
        boonEntries: entries.filter((entry) => (entry.kind || '').toLowerCase() === 'boon'),
        baneEntries: entries.filter((entry) => (entry.kind || '').toLowerCase() === 'bane'),
        availableSkills: result.available_skills
      });
    } finally {
      this.set('catalogueLoading', false);
    }
  },

  actions: {
    openPicker() {
      this.setProperties({ pickerOpen: true, selectedCatalogueEntry: null, requestError: null, query: '' });
      this.loadCatalogue();
    },
    closePicker() {
      this.set('pickerOpen', false);
    },
    search() {
      return this.loadCatalogue();
    },
    pick(entry) {
      this.setProperties({
        selectedCatalogueEntry: entry, requestLevel: 'minor',
        requestSkills: [], requestExplanation: '', requestError: null
      });
    },
    backToList() {
      this.set('selectedCatalogueEntry', null);
    },
    selectRequestSkills(skills) {
      this.set('requestSkills', skills);
    },
    async submitRequest() {
      this.set('isSubmitting', true);
      try {
        let skills = (this.requestSkills || []).map((skill) => skill.key);
        let result = await this.api.requestOne('soulBnbRequest', {
          catalogue_ref: this.selectedCatalogueEntry.id,
          level_state: this.requestLevel || 'minor',
          explanation: this.requestExplanation,
          associated_skills: skills
        }, null);
        if (result.error) {
          this.set('requestError', result.error);
          return;
        }
        this.setProperties({ pickerOpen: false, selectedCatalogueEntry: null });
        await this.loadList();
      } finally {
        this.set('isSubmitting', false);
      }
    },
    showDetail(entry) {
      this.setProperties({ detailEntry: entry, detailOpen: true });
    },
    closeDetail() {
      this.set('detailOpen', false);
    }
  }
});

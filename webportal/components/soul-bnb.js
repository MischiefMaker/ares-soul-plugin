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
  page: 1,
  perPage: 10,

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

  async loadCatalogue(page) {
    this.set('catalogueLoading', true);
    try {
      let result = await this.api.requestOne('soulBnbCatalogue', {
        page: page || this.page, per_page: this.perPage, query: this.query
      }, null);
      this.setProperties({
        catalogueEntries: result.entries, page: result.page, totalPages: result.total_pages,
        availableSkills: result.available_skills
      });
    } finally {
      this.set('catalogueLoading', false);
    }
  },

  actions: {
    openPicker() {
      this.setProperties({ pickerOpen: true, selectedCatalogueEntry: null, requestError: null, query: '' });
      this.loadCatalogue(1);
    },
    closePicker() {
      this.set('pickerOpen', false);
    },
    search() {
      return this.loadCatalogue(1);
    },
    previousPage() {
      if (this.page > 1) {
        this.loadCatalogue(this.page - 1);
      }
    },
    nextPage() {
      if (this.page < this.totalPages) {
        this.loadCatalogue(this.page + 1);
      }
    },
    pick(entry) {
      this.setProperties({
        selectedCatalogueEntry: entry, requestLevel: 'minor',
        requestSkills: '', requestExplanation: '', requestError: null
      });
    },
    backToList() {
      this.set('selectedCatalogueEntry', null);
    },
    async submitRequest() {
      this.set('isSubmitting', true);
      try {
        let skills = (this.requestSkills || '')
          .split(',').map((key) => key.trim()).filter((key) => key.length);
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

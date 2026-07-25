import Component from '@ember/component';
import { inject as service } from '@ember/service';

export default Component.extend({
  tagName: '',
  api: service('game-api'),
  session: service(),
  toolsOpen: false,

  didReceiveAttrs() {
    this._super(...arguments);
    let viewerId = this.get('session.data.authenticated.id');
    let participants = this.get('scene.participants') || [];
    let isParticipant = participants.some((participant) => {
      return `${participant.id}` === `${viewerId}`;
    });
    let custom = this.custom || {};
    this.set(
      'canViewSheets',
      !!custom.soul_can_manage_soul ||
        (!!custom.soul_can_review_rolls && isParticipant)
    );
  },

  actions: {
    async openTools() {
      this.set('toolsOpen', true);
      if (!this.catalogueEntries) {
        let result = await this.api.requestOne('soulBnbCatalogue', { per_page: 1000 }, null);
        if (!result.error) {
          this.set('catalogueEntries', result.entries);
        }
      }
    },
    closeTools() {
      this.set('toolsOpen', false);
    },
    selectBnbReference(entry) {
      this.set('bnbReference', entry);
    },
    async lookupBnb() {
      if (!this.bnbReference) {
        return;
      }
      let result = await this.api.requestOne('soulBnbHere', {
        scene_id: this.get('scene.id'),
        reference: this.bnbReference.tag
      }, null);
      if (!result.error) {
        this.set('bnbMatches', result.matches || []);
      }
    },
    selectParticipant(participant) {
      this.set('selectedParticipant', participant);
    },
    async viewSheet() {
      let result = await this.api.requestOne('soulSheet', {
        character: this.selectedParticipant.name,
        scene_id: this.get('scene.id')
      }, null);
      if (!result.error) {
        this.set('participantSheet', result);
      }
    }
  }
});

import Component from '@ember/component';
import { inject as service } from '@ember/service';

export default Component.extend({
  tagName: '',
  api: service('game-api'),
  session: service(),

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
    async lookupBnb() {
      let result = await this.api.requestOne('soulBnbHere', {
        scene_id: this.get('scene.id'),
        reference: this.bnbReference
      });
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
      });
      if (!result.error) {
        this.set('participantSheet', result);
      }
    }
  }
});

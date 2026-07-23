import Component from '@ember/component';
import { set } from '@ember/object';
import { inject as service } from '@ember/service';

export default Component.extend({
  tagName: '',
  api: service('game-api'),
  flashMessages: service(),
  session: service(),

  rollOpen: false,
  gmReviewOpen: false,
  rollStage: 'setup',
  gmReviewStage: 'list',
  isLoading: false,
  gmIsLoading: false,

  didReceiveAttrs() {
    this._super(...arguments);
    this.updateReviewPermission();
  },

  updateReviewPermission() {
    let custom = this.custom || {};
    let viewerId = this.get('session.data.authenticated.id');
    let participants = this.get('scene.participants') || [];
    let isParticipant = participants.some((participant) => {
      return `${participant.id}` === `${viewerId}`;
    });

    this.set(
      'canReview',
      !!custom.soul_can_manage_soul ||
        (!!custom.soul_can_review_rolls && isParticipant)
    );
  },

  async loadRollData() {
    this.set('isLoading', true);
    try {
      let [sheet, difficultyResponse, pendingResponse] = await Promise.all([
        this.api.requestOne('soulSheet', {}, null),
        this.api.requestOne('soulRollDifficulties', {}, null),
        this.api.requestOne('soulRoll', {}, null)
      ]);
      if (sheet.error || difficultyResponse.error || pendingResponse.error) {
        return;
      }

      let skills = [];
      (sheet.aspects || []).forEach((aspect) => {
        (aspect.skills || []).forEach((skill) => skills.push(skill));
      });

      let difficultyTable = difficultyResponse.difficulties || {};
      let difficulties = Object.keys(difficultyTable).map((key) => {
        return {
          key,
          target: difficultyTable[key],
          name: key
            .split('_')
            .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
            .join(' ')
        };
      });

      this.setProperties({
        skills,
        difficulties,
        selectedSkill: this.selectedSkill || skills[0],
        selectedDifficulty:
          this.selectedDifficulty ||
          difficulties.find((entry) => entry.key === 'standard') ||
          difficulties[0]
      });

      if (pendingResponse.pending_roll) {
        await this.showPendingRoll(pendingResponse.pending_roll);
      } else {
        this.setProperties({
          rollStage: 'setup',
          pendingRoll: null,
          candidates: [],
          rollResult: null,
          additionalTags: null
        });
      }
    } finally {
      this.set('isLoading', false);
    }
  },

  async loadPendingAndHistory() {
    let [pending, history] = await Promise.all([
      this.api.requestOne('soulRollPending', {}, null),
      this.api.requestOne('soulRollHistory', {}, null)
    ]);
    if (!pending.error) {
      this.set('pendingRolls', pending.pending_rolls || []);
    }
    if (!history.error) {
      this.set('rollHistory', history.rolls || []);
    }
  },

  async abortRoll(pending, force) {
    let reason = force ? this.forceAbortReason : this.abortReason;
    if (!reason) {
      this.flashMessages.danger('An abort reason is required.');
      return;
    }
    let result = await this.api.requestOne(
      force ? 'soulRollForceAbort' : 'soulRollAbort',
      { pending_roll_id: pending.id, reason },
      null
    );
    if (!result.error) {
      this.flashMessages.success('Pending SOUL roll aborted.');
      await this.loadRollData();
      await this.loadPendingAndHistory();
      if (force) {
        await this.loadGmReviews();
      }
    }
  },

  async showPendingRoll(pending) {
    this.setProperties({
      pendingRoll: pending,
      rollResult: null,
      additionalTags: null
    });

    if (pending.status === 'awaiting_selection') {
      await this.loadPlayerCandidates(pending.id);
    } else {
      this.setProperties({
        rollStage: 'awaiting_gm',
        candidates: []
      });
    }
  },

  async loadPlayerCandidates(pendingRollId) {
    let response = await this.api.requestOne(
      'soulRollCandidates',
      { pending_roll_id: pendingRollId },
      null
    );
    if (response.error) {
      return;
    }

    let candidates = (response.candidates || []).map((candidate) => {
      return Object.assign({}, candidate, { selected: true });
    });
    this.setProperties({
      candidates,
      rollStage: 'selection'
    });
  },

  async startRoll(gmRequested) {
    if (!this.selectedSkill || !this.selectedDifficulty) {
      this.flashMessages.danger('Select a Skill and difficulty first.');
      return;
    }

    this.set('isLoading', true);
    try {
      let response = await this.api.requestOne(
        gmRequested ? 'soulRollGm' : 'soulRollStart',
        {
          scene_id: this.get('scene.id'),
          skill_key: this.selectedSkill.key,
          difficulty: this.selectedDifficulty.key
        },
        null
      );
      if (!response.error) {
        await this.showPendingRoll(response.pending_roll);
      }
    } finally {
      this.set('isLoading', false);
    }
  },

  async resolvePlayerSelection() {
    let selectedTags = (this.candidates || [])
      .filter((candidate) => !candidate.mandatory && candidate.selected)
      .map((candidate) => candidate.tag);
    let manualTags = (this.additionalTags || '')
      .split(/\s+/)
      .map((tag) => tag.trim())
      .filter((tag) => tag.length > 0);
    let tags = selectedTags.concat(manualTags);
    let args = {
      pending_roll_id: this.pendingRoll.id
    };

    if (tags.length > 0) {
      args.tags = tags;
    } else {
      args.selection = 'none';
    }

    this.set('isLoading', true);
    try {
      let response = await this.api.requestOne('soulRollSelect', args, null);
      if (!response.error) {
        this.setProperties({
          rollResult: response.roll,
          rollStage: 'result',
          pendingRoll: null
        });
      }
    } finally {
      this.set('isLoading', false);
    }
  },

  async loadGmReviews() {
    this.set('gmIsLoading', true);
    try {
      let response = await this.api.requestOne(
        'soulRollReview',
        { scene_id: this.get('scene.id') },
        null
      );
      if (!response.error) {
        this.setProperties({
          gmPendingRolls: response.pending_rolls || [],
          selectedGmRoll: null,
          gmCandidates: [],
          gmReviewStage: 'list'
        });
      }
    } finally {
      this.set('gmIsLoading', false);
    }
  },

  async loadGmCandidates(pending) {
    this.set('gmIsLoading', true);
    try {
      let response = await this.api.requestOne(
        'soulRollReview',
        { pending_roll_id: pending.id },
        null
      );
      if (!response.error) {
        let candidates = (response.candidates || []).map((candidate) => {
          return Object.assign({}, candidate, {
            mandatory: false,
            optional: false
          });
        });
        this.setProperties({
          selectedGmRoll: pending,
          gmCandidates: candidates,
          gmReviewStage: 'candidates'
        });
      }
    } finally {
      this.set('gmIsLoading', false);
    }
  },

  async submitGmSelections() {
    let mandatoryTags = (this.gmCandidates || [])
      .filter((candidate) => candidate.mandatory)
      .map((candidate) => candidate.tag);
    let optionalTags = (this.gmCandidates || [])
      .filter((candidate) => candidate.optional)
      .map((candidate) => candidate.tag);

    this.set('gmIsLoading', true);
    try {
      let response = await this.api.requestOne(
        'soulRollMark',
        {
          pending_roll_id: this.selectedGmRoll.id,
          mandatory_tags: mandatoryTags,
          optional_tags: optionalTags
        },
        null
      );
      if (!response.error) {
        this.flashMessages.success('SOUL roll selections submitted.');
        await this.loadGmReviews();
      }
    } finally {
      this.set('gmIsLoading', false);
    }
  },

  actions: {
    async openRoll() {
      this.set('rollOpen', true);
      await this.loadRollData();
      await this.loadPendingAndHistory();
    },

    closeRoll() {
      this.set('rollOpen', false);
    },

    selectSkill(skill) {
      this.set('selectedSkill', skill);
    },

    selectDifficulty(difficulty) {
      this.set('selectedDifficulty', difficulty);
    },

    async startRoll(gmRequested) {
      await this.startRoll(gmRequested);
    },

    togglePlayerCandidate(candidate, event) {
      if (!candidate.mandatory) {
        set(candidate, 'selected', event.target.checked);
      }
    },

    selectAllCandidates() {
      (this.candidates || []).forEach((candidate) => {
        if (!candidate.mandatory) {
          set(candidate, 'selected', true);
        }
      });
    },

    clearOptionalCandidates() {
      (this.candidates || []).forEach((candidate) => {
        if (!candidate.mandatory) {
          set(candidate, 'selected', false);
        }
      });
    },

    async resolvePlayerSelection() {
      await this.resolvePlayerSelection();
    },

    async refreshPendingRoll() {
      await this.loadRollData();
      await this.loadPendingAndHistory();
    },

    showPendingRoll(pending) {
      return this.showPendingRoll(pending);
    },

    abortRoll(pending) {
      return this.abortRoll(pending, false);
    },

    forceAbortRoll(pending) {
      return this.abortRoll(pending, true);
    },

    forceAbortById() {
      if (!this.forceAbortRollId) {
        this.flashMessages.danger('A pending roll ID is required.');
        return;
      }
      return this.abortRoll({ id: this.forceAbortRollId }, true);
    },

    newRoll() {
      this.setProperties({
        rollStage: 'setup',
        rollResult: null,
        candidates: [],
        additionalTags: null
      });
    },

    async openGmReview() {
      this.set('gmReviewOpen', true);
      await this.loadGmReviews();
    },

    closeGmReview() {
      this.set('gmReviewOpen', false);
    },

    async loadGmCandidates(pending) {
      await this.loadGmCandidates(pending);
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
      await this.submitGmSelections();
    },

    backToGmList() {
      this.setProperties({
        selectedGmRoll: null,
        gmCandidates: [],
        gmReviewStage: 'list'
      });
    }
  }
});

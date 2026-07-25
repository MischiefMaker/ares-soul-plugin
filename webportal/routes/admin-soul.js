// Admin "SOUL management" page route. Automatically installed to
// ares-webportal/app/routes/ via plugin/install. Requires a matching
// route registration in the game's app/custom-routes.js (see
// custom-install/custom-routes.snippet.js) and, to appear in the Admin
// dropdown, a top_navbar entry in game/config/website.yml (see
// custom-install/website_top_navbar.snippet.yml).
//
// Server-side authorization (manage_soul, via SoulStaffWebHandler /
// SoulBnbWebHandler's staff_commands gate) is the actual gate - this
// route doesn't duplicate that check client-side.
import Route from '@ember/routing/route';
import { inject as service } from '@ember/service';
import RSVP from 'rsvp';

export default Route.extend({
  gameApi: service(),

  model() {
    return RSVP.hash({
      requests: this.gameApi.requestOne('soulBnbRequestsList', { status: 'pending' }, 'home')
        .then((response) => response.requests || []),
      // Every character, not just approved ones - matches Jobs'/Inklings'
      // own "characters" fetch for an admin character-picker dropdown
      // (select: 'all').
      characters: this.gameApi.requestMany('characters', { select: 'all' }),
      // A large per_page effectively defeats pagination for this
      // dropdown-population use - same convention as soul-staff.js's own
      // catalogue picker.
      catalogue: this.gameApi.requestOne('soulBnbCatalogue', { per_page: 1000 }, 'home'),
      // Scenes plugin's own "scenes" command (plugins/scenes/web/
      // get_scenes_handler.rb) - already a hard dependency (SOUL posts
      // rolls into scenes via Scenes.add_to_scene). "Recent" is capped at
      // ~20 server-side, plenty for a dropdown; a scene older than that
      // isn't realistically the target of a fresh XP award anyway.
      scenes: this.gameApi.requestOne('scenes', { filter: 'Recent' }, 'home')
        .then((response) => response.scenes || [])
    });
  }
});

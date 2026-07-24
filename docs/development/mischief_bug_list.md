1. Using bnb command gives: Translation missing: en.soul.bnb_own_title -- Codex fixing with message:
         > Confirmed. The newer `+bnb` ownership display references six locale keys that were missing:

          - `bnb_own_title`
          - `bnb_own_line`
          - `bnb_your`
          - `bnb_your_explanation`
          - `bnb_whose`
          - `bnb_whose_explanation`

            Added all six and made the detail label generic so it remains compatible across the command versions. YAML parsing and `git diff --check` pass.

            After this is pushed and installed, restart the game so AresMUSH reloads the locale file. The fix is currently local and not yet pushed.
  
4.  SOUL tab on web chargen does not load anything. Profile now says: WeakMap key null must be an object or an unregistered symbol -- Codex is fixing with message:
         > I found a definite chargen bug: both the MUSH and web chargen paths required the normal play permission, which unapproved characters commonly do not have, and the web component silently discarded that error—hence the empty tab. I’m removing that inappropriate gate while retaining the unapproved-only restriction. I’m also replacing the profile XP form’s legacy input/mutation helpers with the component/action pattern used elsewhere, which avoids passing nullish state through Ember’s helper internals—the likely source of the WeakMap exception introduced on the profile.

5. Getting "More context objects were passed than there are dynamic segments for the route: error" on the web when trying to browse any page after loading a profile.
6. bnbs need to take 'impacted skills' when adding them to a player, so that the roll command knows what to suggest. This could be added in a second step, but it needs to be required and explained, including in chargen.

7. CG help says:
          These commands stop working after approval. Skill ratings cost one point per
          rating level and cannot exceed the starting cap shown by +soul/cg. Aspect
          ratings cost one point per rating level and cannot exceed the configured
          Aspect max rating (default 5) shown by +soul/cg. Unlike Skills, Aspects
          have no post-chargen advancement path, so choose carefully.
          
          A bare +chargen won't reach these commands — core AresMUSH's own chargen
          system claims that word (it's shorthand for the +cg review command). SOUL's
          chargen commands live under +soul/cg specifically to avoid that collision.
    This is wrong: Aspects will allow post-chargen advancement. Resonance does not allow changing after chargen. Everything else does.
   Remove the language about the chargen command. Players do not care. Just tell them the commands they need.


   

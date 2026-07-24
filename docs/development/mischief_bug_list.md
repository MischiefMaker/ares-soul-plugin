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
  
4.  SOUL tab on web chargen does not load anything. Profile now says: WeakMap key null must be an object or an unregistered symbol -- Codex tried to fix with message below, but problem remains:
   
         > I found a definite chargen bug: both the MUSH and web chargen paths required the normal play permission, which unapproved characters commonly do not have, and the web component silently discarded that error—hence the empty tab. I’m removing that inappropriate gate while retaining the unapproved-only restriction. I’m also replacing the profile XP form’s legacy input/mutation helpers with the component/action pattern used elsewhere, which avoids passing nullish state through Ember’s helper internals—the likely source of the WeakMap exception introduced on the profile.

6. Getting "More context objects were passed than there are dynamic segments for the route: error" on the web when trying to browse any page after loading a profile. -- Codex tried to fix with message below, but the problem remains.
   > Confirmed and fixed the root cause.

         The profile loaded legacy Ember template syntax, causing the initial `WeakMap key null` exception. The later “More context objects…” route error was a cascading error-state failure.

          Fixes completed:
         - Updated all SOUL web templates to current Ember property syntax.
         - Fixed the chargen permission gate for unapproved characters.
         - Made chargen display API errors instead of silently showing an empty tab.
         - Corrected related XP input bindings.
         - Verified the complete SOUL UI within a fresh Ares web portal checkout.
         
         The production Ember build now completes successfully. Changes remain local and have not yet been pushed.

7. bnbs need to take 'impacted skills' when adding them to a player, so that the roll command knows what to suggest. This could be added in a second step, but it needs to be required and explained, including in chargen.

8. CG help says:
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

9. We need to add explanations how to disable FS3, including de-listing it in chargen, including: disabling the plugin, removing the chargen steps and app_review_commands for sheet.
  
10. Installers should add to app_review_commands : - soul %{name} -- Note: we should add inkling/list ${name} to the Inkling instructions as well.

11. Add cg checks for: Points spent on Aspects < Points allowed, points spent on skills < points allowed, bnbs < allowed number and ratio as 3 separate items. See inklings for how to implement.
       
12. We were going to include some default bnbs in the install instructions which never got added. Add the following:
         #1 Cursed, Tag: cursed    Kind: bane,         Your character carries some sort of curse.
         #2 Artifact, Tag: artifact    Kind: boon,         Your character possesses some sort of magical artifact that grants them something extra.
         #3 Contacts, tag: contacts         Kind: boon,         Your character knows important people.
         #4 Bad Reputation, tag: bad_rep,         Kind: bane,         Your character has some sort of bad reputation that preceeds them.

13. Using app/approve gives the following error, but does complete the approval:
    
>           %% Sorry! The code lost its mind while executing a command.  Not your fault.
                  Please send this error information to the admins and tell them what you were doing at the time:
                  Description: "app/approve useless"
                  Error: "Ohm::IndexNotFound"
                         2026-07-24 23:22:00 +0000 ERROR - Error in app/approve useless: client=1 error=Ohm::IndexNotFound backtrace=["/home/ares/.rvm/gems/ruby-3.3.6/gems/ohm-3.1.1/lib/ohm.rb:1484:in `to_indices'", "/home/ares/.rvm/gems/ruby-3.3.6/gems/ohm-3.1.1/lib/ohm.rb:1480:in `block in filters'", "/home/ares/.rvm/gems/ruby-3.3.6/gems/ohm-3.1.1/lib/ohm.rb:1480:in `each'", "/home/ares/.rvm/gems/ruby-3.3.6/gems/ohm-3.1.1/lib/ohm.rb:1480:in `map'", "/home/ares/.rvm/gems/ruby-3.3.6/gems/ohm-3.1.1/lib/ohm.rb:1480:in `filters'", "/home/ares/.rvm/gems/ruby-3.3.6/gems/ohm-3.1.1/lib/ohm.rb:823:in `find'", "/home/ares/aresmush/plugins/soul/public/soul_bnb_api.rb:232:in `block in finalize_chargen_grants'", "/home/ares/aresmush/plugins/soul/public/soul_bnb_api.rb:230:in `each'", "/home/ares/aresmush/plugins/soul/public/soul_bnb_api.rb:230:in `finalize_chargen_grants'", "/home/ares/aresmush/plugins/chargen/custom_approval.rb:8:in `custom_approval'"]

14. xp/spend and xp/spend/ability give the following error (which repeats 5 times):
             > %% Sorry! The code lost its mind while executing a command.  Not your fault.
                  Please send this error information to the admins and tell them what you were doing at the time:
                  Description: "xp/spend/aspect mind=1"
                  Error: "wrong number of arguments (given 4, expected 1..3)"
                  
                  %% Sorry! The code lost its mind while executing a command.  Not your fault.
                  Please send this error information to the admins and tell them what you were doing at the time:
                  Description: "xp/spend/aspect mind=1"
                  Error: "wrong number of arguments (given 4, expected 1..3)"
                  
                  %% Sorry! The code lost its mind while executing a command.  Not your fault.
                  Please send this error information to the admins and tell them what you were doing at the time:
                  Description: "xp/spend/aspect mind=1"
                  Error: "wrong number of arguments (given 4, expected 1..3)"
                  
                  %% Sorry! The code lost its mind while executing a command.  Not your fault.
                  Please send this error information to the admins and tell them what you were doing at the time:
                  Description: "xp/spend/aspect mind=1"
                  Error: "wrong number of arguments (given 4, expected 1..3)"
                  
                  %% Sorry! The code lost its mind while executing a command.  Not your fault.
                  Please send this error information to the admins and tell them what you were doing at the time:
                  Description: "xp/spend/aspect mind=1"
                  Error: "wrong number of arguments (given 4, expected 1..3)"
                      > 026-07-24 23:32:48 +0000 ERROR - Error in xp/spend/aspect mind=1: client=2 error=wrong number of arguments (given 4, expected 1..3) backtrace=["/home/ares/aresmush/engine/aresmush/global.rb:8:in `read_config'", "/home/ares/aresmush/plugins/soul/public/soul_xp_api.rb:109:in `calculate_cost'", "/home/ares/aresmush/plugins/soul/commands/soul_xp_cmd.rb:106:in `spend_xp'", "/home/ares/aresmush/plugins/soul/commands/soul_xp_cmd.rb:56:in `handle'", "/home/ares/aresmush/engine/aresmush/plugin/command_handler.rb:25:in `on_command'", "/home/ares/aresmush/engine/aresmush/commands/dispatcher.rb:98:in `block (3 levels) in on_command'", "/home/ares/aresmush/engine/aresmush/error_block.rb:6:in `with_error_handling'", "/home/ares/aresmush/engine/aresmush/commands/dispatcher.rb:93:in `block (2 levels) in on_command'", "/home/ares/aresmush/engine/aresmush/commands/dispatcher.rb:91:in `each'", "/home/ares/aresmush/engine/aresmush/commands/dispatcher.rb:91:in `block in on_command'"]
         > 2026-07-24 23:32:48 +0000 DEBUG - AresMUSH::Soul::SoulXpCmd: ID=2 Enactor=Useless Cmd=xp/spend/aspect mind=1
         2026-07-24 23:32:48 +0000 ERROR - Error in xp/spend/aspect mind=1: client=2 error=wrong number of arguments (given 4, expected 1..3) backtrace=["/home/ares/aresmush/engine/aresmush/global.rb:8:in `read_config'", "/home/ares/aresmush/plugins/soul/public/soul_xp_api.rb:109:in `calculate_cost'", "/home/ares/aresmush/plugins/soul/commands/soul_xp_cmd.rb:106:in `spend_xp'", "/home/ares/aresmush/plugins/soul/commands/soul_xp_cmd.rb:56:in `handle'", "/home/ares/aresmush/engine/aresmush/plugin/command_handler.rb:25:in `on_command'", "/home/ares/aresmush/engine/aresmush/commands/dispatcher.rb:98:in `block (3 levels) in on_command'", "/home/ares/aresmush/engine/aresmush/error_block.rb:6:in `with_error_handling'", "/home/ares/aresmush/engine/aresmush/commands/dispatcher.rb:93:in `block (2 levels) in on_command'", "/home/ares/aresmush/engine/aresmush/commands/dispatcher.rb:91:in `each'", "/home/ares/aresmush/engine/aresmush/commands/dispatcher.rb:91:in `block in on_command'"]
         2026-07-24 23:32:48 +0000 DEBUG - AresMUSH::Soul::SoulXpCmd: ID=2 Enactor=Useless Cmd=xp/spend/aspect mind=1
         2026-07-24 23:32:48 +0000 ERROR - Error in xp/spend/aspect mind=1: client=2 error=wrong number of arguments (given 4, expected 1..3) backtrace=["/home/ares/aresmush/engine/aresmush/global.rb:8:in `read_config'", "/home/ares/aresmush/plugins/soul/public/soul_xp_api.rb:109:in `calculate_cost'", "/home/ares/aresmush/plugins/soul/commands/soul_xp_cmd.rb:106:in `spend_xp'", "/home/ares/aresmush/plugins/soul/commands/soul_xp_cmd.rb:56:in `handle'", "/home/ares/aresmush/engine/aresmush/plugin/command_handler.rb:25:in `on_command'", "/home/ares/aresmush/engine/aresmush/commands/dispatcher.rb:98:in `block (3 levels) in on_command'", "/home/ares/aresmush/engine/aresmush/error_block.rb:6:in `with_error_handling'", "/home/ares/aresmush/engine/aresmush/commands/dispatcher.rb:93:in `block (2 levels) in on_command'", "/home/ares/aresmush/engine/aresmush/commands/dispatcher.rb:91:in `each'", "/home/ares/aresmush/engine/aresmush/commands/dispatcher.rb:91:in `block in on_command'"]
         2026-07-24 23:32:48 +0000 DEBUG - AresMUSH::Soul::SoulXpCmd: ID=2 Enactor=Useless Cmd=xp/spend/aspect mind=1
         2026-07-24 23:32:48 +0000 ERROR - Error in xp/spend/aspect mind=1: client=2 error=wrong number of arguments (given 4, expected 1..3) backtrace=["/home/ares/aresmush/engine/aresmush/global.rb:8:in `read_config'", "/home/ares/aresmush/plugins/soul/public/soul_xp_api.rb:109:in `calculate_cost'", "/home/ares/aresmush/plugins/soul/commands/soul_xp_cmd.rb:106:in `spend_xp'", "/home/ares/aresmush/plugins/soul/commands/soul_xp_cmd.rb:56:in `handle'", "/home/ares/aresmush/engine/aresmush/plugin/command_handler.rb:25:in `on_command'", "/home/ares/aresmush/engine/aresmush/commands/dispatcher.rb:98:in `block (3 levels) in on_command'", "/home/ares/aresmush/engine/aresmush/error_block.rb:6:in `with_error_handling'", "/home/ares/aresmush/engine/aresmush/commands/dispatcher.rb:93:in `block (2 levels) in on_command'", "/home/ares/aresmush/engine/aresmush/commands/dispatcher.rb:91:in `each'", "/home/ares/aresmush/engine/aresmush/commands/dispatcher.rb:91:in `block in on_command'"]
         2026-07-24 23:32:48 +0000 DEBUG - AresMUSH::Soul::SoulXpCmd: ID=2 Enactor=Useless Cmd=xp/spend/aspect mind=1
         2026-07-24 23:32:48 +0000 ERROR - Error in xp/spend/aspect mind=1: client=2 error=wrong number of arguments (given 4, expected 1..3) backtrace=["/home/ares/aresmush/engine/aresmush/global.rb:8:in `read_config'", "/home/ares/aresmush/plugins/soul/public/soul_xp_api.rb:109:in `calculate_cost'", "/home/ares/aresmush/plugins/soul/commands/soul_xp_cmd.rb:106:in `spend_xp'", "/home/ares/aresmush/plugins/soul/commands/soul_xp_cmd.rb:56:in `handle'", "/home/ares/aresmush/engine/aresmush/plugin/command_handler.rb:25:in `on_command'", "/home/ares/aresmush/engine/aresmush/commands/dispatcher.rb:98:in `block (3 levels) in on_command'", "/home/ares/aresmush/engine/aresmush/error_block.rb:6:in `with_error_handling'", "/home/ares/aresmush/engine/aresmush/commands/dispatcher.rb:93:in `block (2 levels) in on_command'", "/home/ares/aresmush/engine/aresmush/commands/dispatcher.rb:91:in `each'", "/home/ares/aresmush/engine/aresmush/commands/dispatcher.rb:91:in `block in on_command'"]
         
         
            

# CUSTOM APP REVIEW SNIPPET - SHOW SOUL DATA IN +app AND +app/review
#
# FILE: aresmush/plugins/chargen/custom_app_review.rb
#       (in your game folder, NOT the plugin folder)
#
# NOTE: This is a SHARED HOOK FILE. On a stock Ares install, custom_app_review
# returns nil and does nothing. If Inklings (or another plugin) already uses
# this same hook, you are MERGING into the existing method, not replacing it -
# see OPTION B.
#
# ===========================================================================
# WHY THIS IS NEEDED
# ===========================================================================
#
# Adding "soul %{name}" to game/config/chargen.yml's app_review_commands
# (see README Step 4) only affects +app/review <character> - it does NOT
# make SOUL data appear in the plain +app <character> checklist or the web
# portal's app-review view. Those two both render AppTemplate, which has
# exactly one plugin extension point: the custom_app_review hook below.
#
# ===========================================================================
# INSTALLATION
# ===========================================================================
#
# STEP 1: Open aresmush/plugins/chargen/custom_app_review.rb in your game
#         folder (not the plugin folder, and not ares-webportal).
# STEP 2: Find the custom_app_review method and check its current body.
# STEP 3: Choose ONE option below based on what's already there:
#           - Method is empty (stock "return nil") -> OPTION A
#           - Method already has content (e.g. Inklings' own
#             "messages = [] ... messages.join("\n")" structure) -> OPTION B
# STEP 4: Reload: load chargen (or restart).
#
# ===========================================================================
# OPTION A: THE METHOD IS EMPTY (STOCK "return nil")
# ===========================================================================

def self.custom_app_review(char)
  Soul.app_review(char)
end

# ===========================================================================
# OPTION B: THE METHOD ALREADY HAS CONTENT (e.g. Inklings is installed)
# ===========================================================================
#
# Inklings' own snippet (custom-install/custom_app_review.snippet.rb in the
# ares-inklings-plugin repo) sets up a "messages" array joined with "\n" at
# the end. Add SOUL to that SAME array rather than introducing a second,
# incompatible combining pattern - do not invent your own array/join scheme
# alongside an existing one. A method already carrying Inklings' integration
# looks like this before you touch it:
#
#   def self.custom_app_review(char)
#     messages = []
#     inkling_review = Inklings.get_app_review_issues(char)
#     messages << inkling_review unless inkling_review.blank?
#     return messages.join("\n")
#   end
#
# Add these two lines - BEFORE "return messages.join("\n")", AFTER
# "messages = []" and any lines already there:
#
#   soul_review = Soul.app_review(char)
#   messages << soul_review unless soul_review.blank?
#
# So the combined method reads:

def self.custom_app_review(char)
  messages = []
  inkling_review = Inklings.get_app_review_issues(char)
  messages << inkling_review unless inkling_review.blank?
  soul_review = Soul.app_review(char)
  messages << soul_review unless soul_review.blank?
  return messages.join("\n")
end

# If a THIRD plugin also uses this hook with its own "messages"/similar
# array, keep its lines too and add SOUL's two lines alongside them - do
# not remove anything already present.
#
# ===========================================================================
# NOTES
# ===========================================================================
#
# - Soul.app_review(char) returns nil (nothing shown) if SOUL is disabled,
#   or if the character hasn't touched chargen's SOUL steps yet (no
#   Resonance set, no Skill/Aspect points spent, no B&B selected) - an
#   application that hasn't reached +soul/cg yet won't show a wall of
#   "unspent points" warnings before the player has had a chance to visit it.
# - Once it does return content, it's a plain string with real newlines
#   (joined with "\n", matching Inklings.get_app_review_issues' own
#   convention for this hook - not SOUL's usual "%r" MUSH markup) showing
#   Resonance (if enabled), Skill/Aspect points spent vs. allowed, and
#   whether the Boon/Bane ratio is currently satisfied - the same readiness
#   data +soul/cg itself shows, reusing SoulChargenWebHandler.status as the
#   single source of truth.
# - Safe to call for an already-approved character too (chargen_allowance
#   and the point/ratio checks don't depend on approval state) - useful if
#   your game also runs +app on approved characters for other reasons.
# - This is purely additive: it doesn't validate or block anything by
#   itself (chargen's own budget/ratio enforcement already prevents
#   over-spending at allocation time - see docs/development/Bug_List.md
#   FR-009). It's just visibility for the reviewing staffer.

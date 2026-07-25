# CUSTOM APP REVIEW SNIPPET - SHOW SOUL DATA IN +app AND +app/review
#
# FILE: aresmush/plugins/chargen/custom_app_review.rb
#       (in your game folder, NOT the plugin folder)
#

# ===========================================================================
# INSTALLATION
# ===========================================================================
#
# 1. Open aresmush/plugins/chargen/custom_app_review.rb
# 2. Find the custom_app_review method
# 3. Follow OPTION A or OPTION B below, depending on whether the method
#    already returns something (e.g. because Inklings or another plugin is
#    already using this same hook)
# 4. Reload chargen: load chargen
#
# ===========================================================================
# OPTION A: THE METHOD IS EMPTY (STOCK "return nil")
# ===========================================================================

def self.custom_app_review(char)
  Soul.app_review(char)
end

# ===========================================================================
# OPTION B: THE METHOD ALREADY RETURNS SOMETHING (e.g. Inklings is
# already using this hook)
# ===========================================================================
#
# Combine every plugin's content instead of overwriting whichever was
# installed first - collect each part, drop any that are nil, and join with
# a blank line so multiple sections stay visually separated. Example
# combining SOUL with a hypothetical existing Inklings section:

def self.custom_app_review(char)
  parts = []
  parts << AresMUSH::Inklings.app_review(char)   # keep whatever this game's Inklings snippet already calls
  parts << Soul.app_review(char)
  parts.compact.join("%r%r")
end

# ===========================================================================
# NOTES
# ===========================================================================
#
# - Soul.app_review(char) returns nil (nothing shown) if SOUL is
#   disabled, or if the character hasn't touched chargen's SOUL steps yet
#   (no Resonance set, no Skill/Aspect points spent, no B&B selected) - an
#   application that hasn't reached +soul/cg yet won't show a wall of
#   "unspent points" warnings before the player has had a chance to visit it.
# - Once it does return content, it shows Resonance (if enabled),
#   Skill/Aspect points spent vs. allowed, and whether the Boon/Bane ratio
#   is currently satisfied - the same readiness data +soul/cg itself shows,
#   reusing SoulChargenWebHandler.status as the single source of truth.
# - Safe to call for an already-approved character too (chargen_allowance
#   and the point/ratio checks don't depend on approval state) - useful if
#   your game also runs +app on approved characters for other reasons.
# - This is purely additive: it doesn't validate or block anything by
#   itself (chargen's own budget/ratio enforcement already prevents
#   over-spending at allocation time - see docs/development/Bug_List.md
#   FR-009). It's just visibility for the reviewing staffer.

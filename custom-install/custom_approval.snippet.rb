# CUSTOM APPROVAL SNIPPET - RESONANCE LOCKING AND CHARGEN B&B FINALIZATION
#
# FILE: aresmush/plugins/chargen/custom_approval.rb
#       (in your game folder, NOT the plugin folder)
#
# ===========================================================================
# INSTALLATION
# ===========================================================================
#
# 1. Open aresmush/plugins/chargen/custom_approval.rb
# 2. Find the custom_approval method
# 3. Add the two lines shown below inside the method
# 4. Reload chargen: load chargen
#
# ===========================================================================
# CODE TO ADD
# ===========================================================================

AresMUSH::Soul::SoulResonanceApi.lock_at_approval(char)
AresMUSH::Soul::SoulBnbApi.finalize_chargen_grants(char)

# ===========================================================================
# EXAMPLE
# ===========================================================================
#
# def self.custom_approval(char)
#   AresMUSH::Soul::SoulResonanceApi.lock_at_approval(char)
#   AresMUSH::Soul::SoulBnbApi.finalize_chargen_grants(char)
#   # Other approval triggers may be added here
# end
#
# ===========================================================================
# NOTES
# ===========================================================================
#
# This runs after char.is_approved = true persists (see
# https://www.aresmush.com/tutorials/code/hooks/approval-triggers.html).
#
# Both lines are safe to call on every approval, including a re-approval:
#
# - lock_at_approval is a no-op once Resonance is already locked (FINAL
#   REQ-012). If your game doesn't use Resonance (resonance.enabled: false
#   in game/config/soul.yml), it does nothing and can be left in place.
# - finalize_chargen_grants creates the "Gained <B&B>" Narrative History
#   entry for every still-present chargen-selected Boon/Bane (FINAL
#   REQ-011: "create only the feature-specific starting history entries
#   required" at approval, not before) - it skips any entry that already
#   has one, so a re-approval never creates a duplicate. If a character
#   has no chargen-sourced B&Bs, it does nothing.

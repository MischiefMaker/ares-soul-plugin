# CUSTOM APPROVAL SNIPPET - RESONANCE LOCKING
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
# 3. Add the line shown below inside the method
# 4. Reload chargen: load chargen
#
# ===========================================================================
# CODE TO ADD
# ===========================================================================

AresMUSH::Soul::SoulResonanceApi.lock_at_approval(char)

# ===========================================================================
# EXAMPLE
# ===========================================================================
#
# def self.custom_approval(char)
#   AresMUSH::Soul::SoulResonanceApi.lock_at_approval(char)
#   # Other approval triggers may be added here
# end
#
# ===========================================================================
# NOTES
# ===========================================================================
#
# This runs after char.is_approved = true persists (see
# https://www.aresmush.com/tutorials/code/hooks/approval-triggers.html).
# It is safe to call on every approval, including a re-approval - it's a
# no-op if Resonance is already locked (FINAL REQ-012). If your game
# doesn't use Resonance (resonance.enabled: false in game/config/soul.yml),
# this line does nothing and can be left in place.

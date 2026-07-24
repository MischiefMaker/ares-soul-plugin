# CUSTOM SCENE DATA SNIPPET - SOUL ROLL REVIEW GATING
#
# FILE: aresmush/plugins/scenes/custom_scene_data.rb
#       (in your game folder, NOT the plugin folder)
#
# PURPOSE
# ===========================================================================
# Lets the web portal know, for the currently logged-in viewer, whether they
# might be able to review GM-assisted rolls in a scene - WITHOUT the widget
# having to guess by calling a permission-gated operation and reacting to a
# "permission denied" response (which would be poor UX for the very common
# case of an ordinary player who was never going to see the GM review panel
# anyway).
#
# This is UI-gating ONLY. The actual authorization check remains entirely
# server-side and unchanged in SoulRollApi/SoulRollWebHandler - a client that
# ignores or spoofs this flag still can't do anything the real permission
# check would reject. See docs/handoffs/Phase_9_Scene_Page_Roll_Widget.md.
#
# ===========================================================================
# INSTALLATION
# ===========================================================================
#
# CHOOSE ONE OPTION based on your current code:
#
# OPTION A: METHOD IS EMPTY (only has "return nil")
# ---------------------------------------------------------------------------
# Replace the ENTIRE method with this:

def self.custom_scene_data(viewer)
  {
    soul_can_review_rolls: Soul.can_review_rolls?(viewer),
    soul_can_manage_soul: Soul.can_manage_soul?(viewer)
  }
end

# OPTION B: METHOD ALREADY RETURNS OTHER PLUGINS' DATA
# ---------------------------------------------------------------------------
# Add these two lines to the existing hash instead of replacing the method:

      soul_can_review_rolls: Soul.can_review_rolls?(viewer),
      soul_can_manage_soul: Soul.can_manage_soul?(viewer)

# NOTE: this hash is viewer-level, not scene-specific - it does not tell you
# whether the viewer participates in any particular scene. Combine it with
# the scene's own participant list (already part of the base scene payload
# every scene page already receives) to decide whether to show the GM review
# panel: soul_can_manage_soul, OR (soul_can_review_rolls AND the viewer is
# a participant in this scene). This matches SoulRollApi.can_review_pending?
# exactly - see plugin/public/soul_roll_api.rb.

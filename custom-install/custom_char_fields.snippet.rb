# CUSTOM CHARACTER FIELDS - SOUL
#
# FILE: aresmush/plugins/profile/custom_char_fields.rb
#       (in your game checkout, not in the SOUL plugin folder)
#
# These fields let the optional profile snippets decide whether to display
# the SOUL tab and whether the profile belongs to the logged-in viewer.
#
# OPTION A: THE METHOD IS EMPTY
# =============================
#
# If get_fields_for_viewing only initializes and returns an empty hash,
# replace the entire method with this:

def self.get_fields_for_viewing(char, viewer)
  fields = {}
  fields[:soul_enabled] = Global.read_config("soul", "enabled") != false
  fields[:can_manage_soul] = Soul.can_manage_soul?(viewer)
  fields[:is_approved] = char.is_approved?
  fields[:viewer_id] = viewer ? viewer.id : nil
  return fields
end

# OPTION B: THE METHOD ALREADY HAS CUSTOM FIELDS
# ===============================================
#
# Add the following lines after "fields = {}" and before "return fields":
#
#   fields[:soul_enabled] = Global.read_config("soul", "enabled") != false
#   fields[:can_manage_soul] = Soul.can_manage_soul?(viewer)
#   fields[:is_approved] = char.is_approved?
#   fields[:viewer_id] = viewer ? viewer.id : nil
#
# CROSS-PLUGIN COMPATIBILITY:
#
# Inklings and other plugins may already add is_approved and viewer_id to
# this same method. If an equivalent key is already present, do not add a
# duplicate under a SOUL-specific name. Reuse the existing key and retain
# its existing line. Both values describe the same profile character and
# logged-in viewer.
#
# If an existing plugin uses different shared key names, keep those names
# and update both SOUL profile snippets to reference them.
#
# A combined method might look like:
#
#   def self.get_fields_for_viewing(char, viewer)
#     fields = {}
#     fields[:some_other_field] = ...
#     fields[:soul_enabled] = Global.read_config("soul", "enabled") != false
#     fields[:can_manage_soul] = Soul.can_manage_soul?(viewer)
#     fields[:is_approved] = char.is_approved?
#     fields[:viewer_id] = viewer ? viewer.id : nil
#     return fields
#   end
#
# Save the file and restart the game after installing the snippet.

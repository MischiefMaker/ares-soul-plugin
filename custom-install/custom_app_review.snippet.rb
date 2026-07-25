# CUSTOM APP REVIEW SNIPPET - SHOW SOUL DATA IN +app AND +app/review
#
# FILE: aresmush/plugins/chargen/custom_app_review.rb
#       (in your game folder, NOT the plugin folder)
#
# STEP 1: Open the file above.
# STEP 2: Check the current custom_app_review method body.
#           - Empty ("return nil") -> use OPTION A
#           - Already has content (e.g. Inklings is installed) -> use OPTION B
# STEP 3: Reload: load chargen (or restart).
#
# ===========================================================================
# OPTION A: THE METHOD IS EMPTY
# ===========================================================================

def self.custom_app_review(char)
  Soul.app_review(char)
end

# ===========================================================================
# OPTION B: THE METHOD ALREADY HAS CONTENT
# ===========================================================================
#
# Add these two lines into the existing method, before its return statement:
#
#   soul_review = Soul.app_review(char)
#   messages << soul_review unless soul_review.blank?
#
# Example combined with Inklings' own integration:

def self.custom_app_review(char)
  messages = []
  inkling_review = Inklings.get_app_review_issues(char)
  messages << inkling_review unless inkling_review.blank?
  soul_review = Soul.app_review(char)
  messages << soul_review unless soul_review.blank?
  return messages.join("\n")
end

module AresMUSH
  module Soul
    def self.plugin_dir
      File.dirname(__FILE__)
    end

    def self.shortcuts
      Global.read_config("soul", "shortcuts") || {}
    end

    def self.enabled?
      Global.read_config("soul", "enabled") != false
    end

    # Whether this character can administer SOUL: award/correct XP, manage
    # the Boon/Bane catalogue, correct Resonance, review the Character
    # Framework, and other staff-only operations (FINAL REQ-005). Permission
    # is configurable via game/config/soul.yml's manage_permission setting;
    # defaults to "manage_apps", the same broad staff-administration
    # permission Inklings uses (plugin/inklings.rb). Override in config if
    # your game's staff structure differs - see docs/reference/
    # Permissions.md. Flat top-level config key, matching the convention
    # used by Inklings' own manage_permission setting rather than a
    # nested hash.
    def self.can_manage_soul?(enactor)
      return false if !enactor
      permission = Global.read_config("soul", "manage_permission") || "manage_apps"
      enactor.has_permission?(permission)
    end

    # Whether this character can perform ordinary player actions: view
    # their own Sheet, spend XP, make rolls, browse the B&B catalogue.
    # Defaults to approved-character status (Character#is_approved?, the
    # same real approval gate used everywhere else in this project - see
    # plugins/chargen/public/chargen_char.rb) rather than a Role
    # permission string, since no bundled AresMUSH plugin registers one
    # that means "is an ordinary approved player" (unlike manage_apps for
    # staff or manage_scenes for scene-GMs - both real, pre-existing
    # permissions). "play" was never a real permission and required
    # every game to invent and assign it by hand before SOUL worked for
    # anyone (found during internal testing, 2026-07-24).
    #
    # play_permission remains available as an optional ADDITIONAL grant,
    # not the sole gate - e.g. to let staff or beta-testers use SOUL
    # before their own character is approved. It is nil (no extra grant)
    # by default.
    def self.can_play?(enactor)
      return false if !enactor
      return true if enactor.is_approved?
      permission = Global.read_config("soul", "play_permission")
      permission && enactor.has_permission?(permission)
    end

    # Whether this character can review/approve GM-assisted pending rolls
    # (FINAL REQ-029). Defaults to "manage_scenes" - a real, pre-existing
    # AresMUSH permission (Scenes plugin: "Can use scene-related admin
    # tools, like stopping or unsharing scenes") that already maps to
    # scene-authority staff. "gm" was never a real permission and
    # required every game to invent and assign it by hand before this
    # worked for anyone (found during internal testing, 2026-07-24).
    def self.can_review_rolls?(enactor)
      return false if !enactor
      permission = Global.read_config("soul", "gm_review_permission") || "manage_scenes"
      enactor.has_permission?(permission)
    end

    # Chargen's own custom_app_review hook (plugins/chargen/custom_app_review.rb
    # in the game folder, see custom-install/custom_app_review.snippet.rb) is
    # the only extension point AresMUSH's core +app / +app/review checklist
    # offers - it's called for both, so this single method covers the MUSH
    # command and the web portal's app-review view alike. Distinct from
    # get_cmd_handler/get_web_request_handler above (those register SOUL's
    # own commands/operations); this is SOUL supplying content into a
    # *different* plugin's hook, so it lives at the Soul module's own
    # public-API level rather than a dedicated command/handler class.
    #
    # Returns nil (nothing shown) if SOUL is disabled or the character has
    # no chargen data yet (SoulResonanceApi never set, no Skills/Aspects/B&Bs
    # touched) - an application that hasn't reached SOUL's chargen steps
    # yet shouldn't show a wall of "unspent points" warnings before the
    # player has had a chance to visit +soul/cg at all.
    def self.app_review(char)
      return nil unless char && enabled?
      status = SoulChargenWebHandler.status(char)
      return nil if status[:resonance].nil? && status[:points_spent].zero? &&
        status[:aspect_points_spent].zero? && !status[:has_selected_bnb]

      lines = []
      if status[:resonance_enabled]
        resonance_display = status[:resonance].nil? ? t('chargen.not_set') : "R#{status[:resonance]}"
        # Non-blocking heads-up for an extreme Resonance value (2026-07-25
        # live testing: "I'd like to default add a 'warn' on R3 and R-3
        # on the 'app <name>' view... Not a block to applying") - this
        # checklist is purely informational either way, so there's
        # nothing further to gate.
        warning = SoulResonanceApi.warning_label(status[:resonance])
        resonance_display = "#{resonance_display} %xy<  #{warning}  >%xn" if warning
        lines << Chargen.format_review_status("Checking SOUL Resonance.", resonance_display)
      end
      lines << Chargen.format_review_status("Checking SOUL Skill points.",
        "#{status[:points_spent]}/#{status[:skill_points]} " +
        (status[:skill_points_fully_spent] ? t('chargen.ok') : t('chargen.not_set')))
      lines << Chargen.format_review_status("Checking SOUL Aspect points.",
        "#{status[:aspect_points_spent]}/#{status[:aspect_points]} " +
        (status[:aspect_points_fully_spent] ? t('chargen.ok') : t('chargen.not_set')))
      lines << Chargen.format_review_status("Checking SOUL Boon/Bane ratio.",
        status[:bnb_ratio_satisfied] ? t('chargen.ok') : t('chargen.not_set'))
      # "\n", not "%r" - matches Inklings.get_app_review_issues' own join
      # (plugin/inklings.rb in the Inklings repo), the verified real
      # convention for this specific hook's return value.
      lines.join("\n")
    end

    # Shared MUSH-only display helper (2026-07-26 live testing: "wherever
    # boons and banes are displayed, like on the soul sheet, let's use red
    # for banes and green for boons") - a plain ANSI color code, not
    # meaningful to the web portal, so it lives here (used by both
    # SoulBnbCmd and SoulSheetCmd) rather than on SoulBnbApi, which both
    # MUSH and web share.
    def self.bnb_kind_color(catalogue_entry)
      return "%xg" if catalogue_entry&.boon?
      return "%xr" if catalogue_entry&.bane?
      ""
    end

    # Character-facing notification, mirroring Inklings.notify_player
    # (ares-inklings-plugin/plugin/inklings.rb) exactly: an immediate OOC
    # message if the character is currently connected
    # (Login.emit_ooc_if_logged_in), plus a persistent "bell" notice
    # (Login.notify) keyed to reference_id so it's still there to read
    # later even if they weren't online - guarded by
    # Login.respond_to?(:notify) the same way Inklings guards it, in case
    # an older AresMUSH core predates that API. Gated on
    # soul.notifications.character_facing_success (added in Phase 2,
    # documented since as REQ-044's "Notify players of awards, purchases,
    # corrections" - never actually wired to anything until now; this is
    # its first real caller, currently only for XP awards - see
    # SoulXpApi.award's notify: parameter).
    def self.notify_player(char, message, type:, reference_id: nil)
      return unless char
      return if Global.read_config("soul", "notifications", "character_facing_success") == false

      Login.emit_ooc_if_logged_in(char, message)
      Login.notify(char, type, message, reference_id) if reference_id && Login.respond_to?(:notify)
    end

    # Called once at plugin load and whenever staff reload game config
    # (see plugins/manage/commands/game/load_config_cmd.rb in AresMUSH
    # core) - same convention every bundled plugin uses (e.g.
    # Jobs.check_config, Chargen.check_config). Returns an array of
    # human-readable error strings; an empty array means config is valid.
    def self.check_config
      validator = SoulConfigValidator.new
      validator.validate
    end

    # Dispatched by AresMUSH::Dispatcher#on_event for every fired event,
    # not just cron ticks - see engine/aresmush/commands/dispatcher.rb.
    def self.get_event_handler(event_name)
      return nil unless enabled?

      case event_name
      when "CronEvent"
        return XpCronHandler
      when "SceneSharedEvent"
        return SceneSharedEventHandler
      end
      nil
    end

    def self.get_cmd_handler(client, cmd, enactor)
      return nil unless enabled?

      case cmd.root
      when "soul"
        case cmd.switch
        when "cg", "cg/resonance", "cg/skill", "cg/aspect", "cg/catalogue", "cg/bnb", "cg/drop"
          SoulChargenCmd
        when "history"
          SoulHistoryCmd
        when "framework", "framework/skill", "framework/aspect", "resonance", "reload", "audit"
          SoulStaffCmd
        when nil
          SoulSheetCmd
        end
      when "bnb"
        SoulBnbCmd
      when "xp"
        SoulXpCmd
      when "culmination"
        SoulCulminationCmd
      when "roll"
        SoulRollCmd
      end
    end

    def self.get_web_request_handler(request)
      return nil unless enabled?

      case request.cmd
      when "soulSheet"
        SoulSheetWebHandler
      when "soulBnb", "soulBnbHere", "soulBnbCatalogue", "soulBnbCreate", "soulBnbSetSkills",
           "soulBnbGrant", "soulBnbProgress", "soulBnbAdjustLevel", "soulBnbSetEntrySkills", "soulBnbDelete",
           "soulBnbResolve", "soulBnbRestore", "soulBnbList", "soulBnbRequest", "soulBnbRequestsList",
           "soulBnbRequestApprove", "soulBnbRequestDeny", "soulBnbCharactersWithEntry"
        SoulBnbWebHandler
      when "soulXp", "soulXpSpend", "soulXpAward", "soulXpScene", "soulXpCorrect"
        SoulXpWebHandler
      when "soulCulminations", "soulCulminationPropose", "soulCulminationApprove",
           "soulCulminationDeny", "soulCulminationRevoke", "soulCulminationCorrect"
        SoulCulminationWebHandler
      when "soulHistory"
        SoulHistoryWebHandler
      when "soulFramework", "soulFrameworkCorrect", "soulResonance", "soulReload", "soulAudit"
        SoulStaffWebHandler
      when "soulRoll", "soulRollStart", "soulRollGm", "soulRollSelect",
           "soulRollAbort", "soulRollForceAbort", "soulRollCancelGm", "soulRollPending",
           "soulRollHistory", "soulRollReview", "soulRollOpenForReview", "soulRollMark",
           "soulRollCandidates", "soulRollDifficulties"
        SoulRollWebHandler
      when "soulChargenStatus", "soulChargenResonance", "soulChargenSkill", "soulChargenAspect",
           "soulChargenBnb", "soulChargenDrop"
        SoulChargenWebHandler
      end
    end
  end
end

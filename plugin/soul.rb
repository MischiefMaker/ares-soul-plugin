module AresMUSH
  module Soul
    def self.plugin_dir
      File.dirname(__FILE__)
    end

    def self.shortcuts
      Global.read_config("soul", "shortcuts") || {}
    end

    # Whether this character can administer SOUL: award/correct XP, manage
    # the Boon/Bane catalogue, correct Resonance, review the Character
    # Framework, and other staff-only operations (FINAL REQ-005). Permission
    # is configurable via game/config/soul.yml's manage_permission setting;
    # defaults to "manage_jobs", the same broad staff-administration
    # permission the Jobs plugin uses (see plugins/jobs/helpers.rb in the
    # AresMUSH core). Override in config if your game's staff structure
    # differs - see docs/reference/Permissions.md. Flat top-level config
    # key, matching the convention used by Inklings' own manage_permission
    # setting (plugin/inklings.rb) rather than a nested hash.
    def self.can_manage_soul?(enactor)
      return false if !enactor
      permission = Global.read_config("soul", "manage_permission") || "manage_jobs"
      enactor.has_permission?(permission)
    end

    # Whether this character can perform ordinary player actions: view
    # their own Sheet, spend XP, make rolls, browse the B&B catalogue.
    # Defaults to "play" per FINAL REQ-005's player tier. Kept separate
    # from can_manage_soul? so games can restrict specific player actions
    # (e.g. play_permission: manage_jobs) without touching staff access.
    def self.can_play?(enactor)
      return false if !enactor
      permission = Global.read_config("soul", "play_permission") || "play"
      enactor.has_permission?(permission)
    end

    # Whether this character can review/approve GM-assisted pending rolls
    # (FINAL REQ-029). Defaults to "gm" per REQ-005's scene-GM tier.
    def self.can_review_rolls?(enactor)
      return false if !enactor
      permission = Global.read_config("soul", "gm_review_permission") || "gm"
      enactor.has_permission?(permission)
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
      case event_name
      when "CronEvent"
        return XpCronHandler
      end
      nil
    end

    def self.get_cmd_handler(client, cmd, enactor)
      case cmd.root
      when "soul"
        case cmd.switch
        when "history"
          SoulHistoryCmd
        when "framework", "resonance", "reload", "audit"
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
      case request.cmd
      when "soulSheet"
        SoulSheetWebHandler
      when "soulBnb", "soulBnbCatalogue", "soulBnbCreate", "soulBnbGrant",
           "soulBnbProgress", "soulBnbDelete", "soulBnbResolve", "soulBnbRestore"
        SoulBnbWebHandler
      when "soulXp", "soulXpSpend", "soulXpAward", "soulXpScene", "soulXpCorrect"
        SoulXpWebHandler
      when "soulCulminations", "soulCulminationPropose", "soulCulminationApprove",
           "soulCulminationDeny", "soulCulminationRevoke", "soulCulminationCorrect"
        SoulCulminationWebHandler
      when "soulHistory"
        SoulHistoryWebHandler
      when "soulFramework", "soulResonance", "soulReload", "soulAudit"
        SoulStaffWebHandler
      when "soulRoll", "soulRollStart", "soulRollGm", "soulRollSelect",
           "soulRollAbort", "soulRollForceAbort", "soulRollPending",
           "soulRollHistory", "soulRollReview", "soulRollMark"
        SoulRollWebHandler
      end
    end
  end
end

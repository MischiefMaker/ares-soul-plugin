module AresMUSH
  module Soul
    # Weekly approved-character XP award (FINAL REQ-013's canonical
    # "weekly approved-character award" source). Registered for "CronEvent"
    # in Soul.get_event_handler; fires every minute like every other
    # plugin's cron handler, but only acts when Cron.is_cron_match? matches
    # the configured schedule - the same mechanism FS3Skills' own
    # XpCronHandler and Inklings' InklingXpCronHandler use.
    #
    # Catch-up eligibility (FINAL REQ-014, Addendum §8) is evaluated live by
    # SoulXpApi.award on every award rather than needing a separate
    # recalculation cron - see the comment on SoulXpApi.catchup_eligible?.
    class XpCronHandler
      def on_event(event)
        SoulRollApi.expire_stale_pending_rolls(event.time)

        config = Global.read_config("soul", "xp", "weekly_award_cron")
        return unless Cron.is_cron_match?(config, event.time)

        amount = Global.read_config("soul", "xp", "weekly_award") || 0
        return if amount <= 0

        # ISO week identifier keeps this idempotent even if the cron tick
        # fires more than once within the same matching minute window.
        week_id = event.time.strftime("%G-W%V")

        Chargen.approved_chars.each do |char|
          SoulXpApi.award(
            char,
            amount,
            source: "weekly",
            idempotency_key: "weekly:#{week_id}:#{char.id}",
            apply_catchup: true
          )
        end
      end
    end
  end
end

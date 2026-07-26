require_relative 'spec_helper'

module AresMUSH
  describe Soul do
    describe ".app_review" do
      let(:character) { Fabricate(:character) }

      it "returns nil when SOUL is disabled" do
        allow(Global).to receive(:read_config).with("soul", "enabled").and_return(false)
        expect(Soul.app_review(character)).to be_nil
      end

      it "returns nil when the character hasn't touched any SOUL chargen step yet" do
        allow(Global).to receive(:read_config).with("soul", "enabled").and_return(true)
        allow(SoulChargenWebHandler).to receive(:status).with(character).and_return(
          resonance: nil, points_spent: 0, aspect_points_spent: 0, has_selected_bnb: false
        )
        expect(Soul.app_review(character)).to be_nil
      end

      it "reports readiness once the character has spent Skill points" do
        allow(Global).to receive(:read_config).with("soul", "enabled").and_return(true)
        allow(SoulChargenWebHandler).to receive(:status).with(character).and_return(
          resonance: nil, resonance_enabled: false,
          points_spent: 15, skill_points: 15, skill_points_fully_spent: true,
          aspect_points_spent: 3, aspect_points: 5, aspect_points_fully_spent: false,
          bnb_ratio_satisfied: true, has_selected_bnb: true
        )

        result = Soul.app_review(character)
        expect(result).to match(/SOUL Skill points/)
        expect(result).to match(/SOUL Aspect points/)
        expect(result).to match(/SOUL Boon\/Bane ratio/)
        expect(result).not_to match(/SOUL Resonance/)
      end

      it "includes Resonance when Resonance is enabled" do
        allow(Global).to receive(:read_config).with("soul", "enabled").and_return(true)
        allow(SoulChargenWebHandler).to receive(:status).with(character).and_return(
          resonance: 1, resonance_enabled: true,
          points_spent: 15, skill_points: 15, skill_points_fully_spent: true,
          aspect_points_spent: 5, aspect_points: 5, aspect_points_fully_spent: true,
          bnb_ratio_satisfied: true, has_selected_bnb: false
        )

        expect(Soul.app_review(character)).to match(/SOUL Resonance.*R1/)
      end

      it "returns nil for a nil character" do
        expect(Soul.app_review(nil)).to be_nil
      end
    end

    describe ".get_web_request_handler" do
      # Regression test for a real bug (2026-07-25): SoulBnbWebHandler's own
      # `case request.cmd` grew several new commands (the B&B request
      # workflow, FR-015) that were never added here, so the dispatcher
      # never routed them to the handler at all and every call hit core's
      # generic "Oops! Something went wrong..." fallback
      # (engine/aresmush/commands/dispatcher.rb) instead of ever reaching
      # SoulBnbWebHandler's own real "Character not found"/permission
      # logic. Every cmd string a handler's own case statement recognizes
      # needs to be listed here too - the two are not kept in sync
      # automatically.
      before { allow(Global).to receive(:read_config).with("soul", "enabled").and_return(true) }

      {
        "soulSheet" => SoulSheetWebHandler,
        "soulBnb" => SoulBnbWebHandler, "soulBnbHere" => SoulBnbWebHandler,
        "soulBnbCatalogue" => SoulBnbWebHandler, "soulBnbCreate" => SoulBnbWebHandler,
        "soulBnbSetSkills" => SoulBnbWebHandler, "soulBnbGrant" => SoulBnbWebHandler,
        "soulBnbProgress" => SoulBnbWebHandler, "soulBnbAdjustLevel" => SoulBnbWebHandler,
        "soulBnbSetEntrySkills" => SoulBnbWebHandler,
        "soulBnbDelete" => SoulBnbWebHandler,
        "soulBnbResolve" => SoulBnbWebHandler, "soulBnbRestore" => SoulBnbWebHandler,
        "soulBnbList" => SoulBnbWebHandler, "soulBnbRequest" => SoulBnbWebHandler,
        "soulBnbRequestsList" => SoulBnbWebHandler, "soulBnbRequestApprove" => SoulBnbWebHandler,
        "soulBnbRequestDeny" => SoulBnbWebHandler, "soulBnbCharactersWithEntry" => SoulBnbWebHandler,
        "soulXp" => SoulXpWebHandler, "soulXpSpend" => SoulXpWebHandler,
        "soulXpAward" => SoulXpWebHandler, "soulXpScene" => SoulXpWebHandler,
        "soulXpCorrect" => SoulXpWebHandler,
        "soulCulminations" => SoulCulminationWebHandler, "soulCulminationPropose" => SoulCulminationWebHandler,
        "soulCulminationApprove" => SoulCulminationWebHandler, "soulCulminationDeny" => SoulCulminationWebHandler,
        "soulCulminationRevoke" => SoulCulminationWebHandler, "soulCulminationCorrect" => SoulCulminationWebHandler,
        "soulHistory" => SoulHistoryWebHandler,
        "soulFramework" => SoulStaffWebHandler, "soulFrameworkCorrect" => SoulStaffWebHandler,
        "soulResonance" => SoulStaffWebHandler, "soulReload" => SoulStaffWebHandler,
        "soulAudit" => SoulStaffWebHandler,
        "soulRoll" => SoulRollWebHandler, "soulRollStart" => SoulRollWebHandler,
        "soulRollGm" => SoulRollWebHandler, "soulRollSelect" => SoulRollWebHandler,
        "soulRollAbort" => SoulRollWebHandler, "soulRollForceAbort" => SoulRollWebHandler,
        "soulRollCancelGm" => SoulRollWebHandler,
        "soulRollPending" => SoulRollWebHandler, "soulRollHistory" => SoulRollWebHandler,
        "soulRollReview" => SoulRollWebHandler, "soulRollOpenForReview" => SoulRollWebHandler,
        "soulRollMark" => SoulRollWebHandler,
        "soulRollCandidates" => SoulRollWebHandler, "soulRollDifficulties" => SoulRollWebHandler,
        "soulChargenStatus" => SoulChargenWebHandler, "soulChargenResonance" => SoulChargenWebHandler,
        "soulChargenSkill" => SoulChargenWebHandler, "soulChargenAspect" => SoulChargenWebHandler,
        "soulChargenBnb" => SoulChargenWebHandler, "soulChargenDrop" => SoulChargenWebHandler
      }.each do |cmd, handler_class|
        it "routes #{cmd} to #{handler_class}" do
          request = double(cmd: cmd)
          expect(Soul.get_web_request_handler(request)).to eq(handler_class)
        end
      end

      it "returns nil for an unrecognized command" do
        request = double(cmd: "notARealSoulCommand")
        expect(Soul.get_web_request_handler(request)).to be_nil
      end

      it "returns nil when SOUL is disabled, even for a real command" do
        allow(Global).to receive(:read_config).with("soul", "enabled").and_return(false)
        request = double(cmd: "soulSheet")
        expect(Soul.get_web_request_handler(request)).to be_nil
      end
    end
  end
end

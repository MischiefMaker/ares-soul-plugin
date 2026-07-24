require_relative 'spec_helper'

module AresMUSH
  describe SoulStaffWebHandler do
    it "rechecks management permission" do
      request = double(cmd: "soulAudit", enactor: Fabricate(:character), args: {})
      allow(Website).to receive(:check_login).and_return(nil)
      allow(Soul).to receive(:can_manage_soul?).and_return(false)
      expect(subject.handle(request)[:error]).to be_present
    end

    it "returns audit entries to authorized staff" do
      staff = Fabricate(:character)
      character = Fabricate(:character)
      request = double(cmd: "soulAudit", enactor: staff, args: { 'character' => character.name })
      allow(Website).to receive(:check_login).and_return(nil)
      allow(Soul).to receive(:can_manage_soul?).and_return(true)
      allow(Character).to receive(:find_one_by_name).and_return(character)
      allow(SoulAuditApi).to receive(:get_audit).and_return([])

      result = subject.handle(request)
      expect(result[:entries]).to eq([])
      expect(SoulAuditApi).to have_received(:get_audit).with(character, staff)
    end

    it "does not let the subject view their own audit without management permission" do
      character = Fabricate(:character)
      request = double(cmd: "soulAudit", enactor: character, args: { 'character' => character.name })
      allow(Website).to receive(:check_login).and_return(nil)
      allow(Soul).to receive(:can_manage_soul?).with(character).and_return(false)
      expect(subject.handle(request)[:error]).to be_present
    end

    it "actually validates configuration on reload instead of an unconditional success" do
      staff = Fabricate(:character)
      request = double(cmd: "soulReload", enactor: staff, args: {})
      allow(Website).to receive(:check_login).and_return(nil)
      allow(Soul).to receive(:can_manage_soul?).and_return(true)

      allow(Soul).to receive(:check_config).and_return([])
      expect(subject.handle(request)).to eq(success: true, live_read: true, errors: [])

      allow(Soul).to receive(:check_config).and_return(["bad setting"])
      expect(subject.handle(request)).to eq(success: false, live_read: true, errors: ["bad setting"])
    end

    it "exposes audited framework correction to authorized staff" do
      staff = Fabricate(:character)
      character = Fabricate(:character)
      request = double(cmd: "soulFrameworkCorrect", enactor: staff,
        args: { 'character' => character.name, 'kind' => 'skill',
                'key' => 'blade', 'rating' => 4, 'reason' => 'Repair' })
      allow(Website).to receive(:check_login).and_return(nil)
      allow(Soul).to receive(:can_manage_soul?).and_return(true)
      allow(Character).to receive(:find_one_by_name).and_return(character)
      allow(SoulCharacterApi).to receive(:correct_rating).and_return(success: true)

      subject.handle(request)
      expect(SoulCharacterApi).to have_received(:correct_rating).with(
        character, 'skill', 'blade', 4, actor: staff, reason: 'Repair'
      )
    end
  end
end

require_relative 'spec_helper'

module AresMUSH
  describe Soul::SoulChargenCmd do
    it "is registered for +soul/cg (not a bare +chargen root - see BUG-004)" do
      %w[cg cg/resonance cg/skill cg/bnb cg/drop].each do |switch|
        cmd = double(root: "soul", switch: switch)
        expect(Soul.get_cmd_handler(nil, cmd, nil)).to eq(Soul::SoulChargenCmd)
      end
    end

    describe "#sub_switch" do
      it "strips the cg prefix so the command's own dispatch works unchanged" do
        cmd = double(switch: "cg/resonance")
        handler = Soul::SoulChargenCmd.new(nil, cmd, nil)
        expect(handler.sub_switch).to eq("resonance")
      end

      it "treats a bare cg switch as the status view" do
        cmd = double(switch: "cg")
        handler = Soul::SoulChargenCmd.new(nil, cmd, nil)
        expect(handler.sub_switch).to eq("")
      end
    end

    describe "#check_permission" do
      it "allows an unapproved character even with no play_permission configured (BUG-005)" do
        enactor = double(is_approved?: false)
        handler = Soul::SoulChargenCmd.new(nil, double, enactor)
        expect(handler.check_permission).to be_nil
      end

      it "blocks an already-approved character" do
        enactor = double(is_approved?: true)
        handler = Soul::SoulChargenCmd.new(nil, double, enactor)
        expect(handler.check_permission).to be_present
      end
    end
  end
end

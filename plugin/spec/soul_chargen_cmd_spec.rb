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
  end
end

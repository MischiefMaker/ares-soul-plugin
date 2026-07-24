require_relative 'spec_helper'

module AresMUSH
  describe Soul::SoulChargenCmd do
    it "is registered for +soul/cg (not a bare +chargen root - see BUG-004)" do
      %w[cg cg/resonance cg/skill cg/aspect cg/catalogue cg/bnb cg/drop].each do |switch|
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

      it "strips the cg prefix for the aspect switch" do
        cmd = double(switch: "cg/aspect")
        handler = Soul::SoulChargenCmd.new(nil, cmd, nil)
        expect(handler.sub_switch).to eq("aspect")
      end

      it "strips the cg prefix for the catalogue switch" do
        cmd = double(switch: "cg/catalogue")
        handler = Soul::SoulChargenCmd.new(nil, cmd, nil)
        expect(handler.sub_switch).to eq("catalogue")
      end
    end

    it "lists only chargen-available catalogue entries" do
      allow(SoulBnbApi).to receive(:get_catalogue).and_return([])
      allow(subject).to receive(:client).and_return(double(emit: nil))
      allow(subject).to receive(:t).with('soul.none').and_return("None")
      allow(subject).to receive(:t).with('soul.chargen_catalogue_title').and_return("Catalogue")

      subject.show_catalogue

      expect(SoulBnbApi).to have_received(:get_catalogue).with(chargen_available: true)
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

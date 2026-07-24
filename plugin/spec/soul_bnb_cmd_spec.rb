require_relative 'spec_helper'

module AresMUSH
  describe Soul::SoulBnbCmd do
    it "is registered for +bnb" do
      cmd = double(root: "bnb")
      expect(Soul.get_cmd_handler(nil, cmd, nil)).to eq(Soul::SoulBnbCmd)
    end

    describe "a bare +bnb (no reference)" do
      let(:enactor) { Fabricate(:character) }
      let(:client) { double(emit: nil) }
      let(:cmd) { double(switch: nil, args: "") }

      def handler
        h = Soul::SoulBnbCmd.new(client, cmd, enactor)
        h.parse_args
        h
      end

      it "does not require a reference (a blank +bnb is valid syntax)" do
        expect(handler.required_args).to eq([])
      end

      it "lists the character's own entries, including the private explanation" do
        catalogue = double(id: 12, tag: "cursed", name: "Cursed", kind: "bane")
        entry = double(catalogue_entry: catalogue, level_state: "minor",
          character_explanation: "A witch's grudge.")
        allow(SoulBnbApi).to receive(:get_character_entries).with(enactor).and_return([entry])
        expect(BorderedListTemplate).to receive(:new).with(
          [a_string_matching(/#12 \[cursed\] Cursed \(bane, minor\): A witch's grudge\./)],
          "Your Boons & Banes"
        ).and_return(double(render: "rendered"))

        handler.show_entry
      end

      it "shows 'None' in place of an unset explanation" do
        catalogue = double(id: 3, tag: "lucky", name: "Lucky", kind: "boon")
        entry = double(catalogue_entry: catalogue, level_state: "major", character_explanation: "")
        allow(SoulBnbApi).to receive(:get_character_entries).with(enactor).and_return([entry])
        expect(BorderedListTemplate).to receive(:new).with(
          [a_string_matching(/None/)], "Your Boons & Banes"
        ).and_return(double(render: "rendered"))

        handler.show_entry
      end
    end
  end
end

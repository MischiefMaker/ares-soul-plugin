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

    describe "+bnb/detail (staff viewing another character's own B&Bs)" do
      let(:staff) { Fabricate(:character) }
      let(:target) { Fabricate(:character, name: "Jordan") }
      let(:client) { double(emit: nil, emit_failure: nil) }

      def handler(args)
        cmd = double(switch: "detail", args: args)
        h = Soul::SoulBnbCmd.new(client, cmd, staff)
        h.parse_args
        h
      end

      it "is staff-only" do
        cmd = double(switch: "detail")
        h = Soul::SoulBnbCmd.new(client, cmd, staff)
        allow(Soul).to receive(:can_manage_soul?).with(staff).and_return(false)
        expect(h.check_permission).to be_present
      end

      it "requires only the character, not a reference" do
        h = handler("Jordan")
        expect(h.required_args).to eq(["Jordan"])
      end

      it "lists the target character's entries with a whose-name title" do
        catalogue = double(id: 5, tag: "brave", name: "Brave", kind: "boon")
        entry = double(catalogue_entry: catalogue, level_state: "minor",
          character_explanation: "Ran into a burning building once.")
        allow(SoulBnbApi).to receive(:get_character_entries).with(target).and_return([entry])
        expect(BorderedListTemplate).to receive(:new).with(
          [a_string_matching(/Ran into a burning building/)], "Jordan's Boons & Banes"
        ).and_return(double(render: "rendered"))

        handler("Jordan").show_detail_for(target)
      end

      it "shows a single entry with a whose-explanation label" do
        catalogue = double(id: 5, tag: "brave", name: "Brave", kind: "boon", description: "Fearless.")
        entry = double(catalogue_entry: catalogue, character_explanation: "Ran into a burning building once.")
        allow(SoulBnbApi).to receive(:get_catalogue_entry).with("brave").and_return(catalogue)
        allow(SoulBnbApi).to receive(:get_character_entries).with(target).and_return([entry])
        expect(BorderedDisplayTemplate).to receive(:new).with(
          a_string_matching(/Jordan's explanation/), "#5 Brave"
        ).and_return(double(render: "rendered"))

        handler("Jordan=brave").show_detail_for(target)
      end
    end
  end
end

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

    describe "+bnb/create" do
      let(:enactor) { Fabricate(:character) }
      let(:client) { double(emit_success: nil, emit_failure: nil) }

      def handler(args)
        cmd = double(switch: "create", args: args)
        h = Soul::SoulBnbCmd.new(client, cmd, enactor)
        h.parse_args
        h
      end

      it "parses kind/tag/name/skills=description, splitting the Skill list on commas" do
        h = handler("boon/lucky/Lucky/blade,spirit=You have uncanny good fortune.")
        expect(h.kind).to eq("boon")
        expect(h.tag).to eq("lucky")
        expect(h.name).to eq("Lucky")
        expect(h.skill_associations).to eq(["blade", "spirit"])
        expect(h.description).to eq("You have uncanny good fortune.")
      end

      it "parses a single associated Skill with no comma" do
        h = handler("bane/cursed/Cursed/blade=Bad luck dogs your heels.")
        expect(h.skill_associations).to eq(["blade"])
      end

      it "yields an empty Skill list when the segment is omitted (no fixed default)" do
        h = handler("boon/lucky/Lucky=You have uncanny good fortune.")
        expect(h.skill_associations).to eq([])
      end

      it "passes the parsed Skill list through to SoulBnbApi.create_catalogue_entry" do
        h = handler("boon/lucky/Lucky/blade=You have uncanny good fortune.")
        expect(SoulBnbApi).to receive(:create_catalogue_entry).with(
          name: "Lucky", description: "You have uncanny good fortune.",
          kind: "boon", tag: "lucky", enactor: enactor, skill_associations: ["blade"]
        ).and_return(success: true)

        h.create_entry
      end
    end

    describe "+bnb/skills" do
      let(:enactor) { Fabricate(:character) }
      let(:client) { double(emit_success: nil, emit_failure: nil) }

      def handler(args)
        cmd = double(switch: "skills", args: args)
        h = Soul::SoulBnbCmd.new(client, cmd, enactor)
        h.parse_args
        h
      end

      it "parses <id or tag>=<skill1,skill2,...>" do
        h = handler("lucky=blade,spirit")
        expect(h.reference).to eq("lucky")
        expect(h.skill_associations).to eq(["blade", "spirit"])
      end

      it "requires a non-empty Skill list" do
        h = handler("lucky=")
        expect(h.required_args).to include(nil)
      end

      it "passes through to SoulBnbApi.set_skill_associations" do
        h = handler("lucky=blade")
        expect(SoulBnbApi).to receive(:set_skill_associations).with(
          "lucky", ["blade"], enactor: enactor
        ).and_return(success: true)

        h.set_skills_entry
      end
    end

    describe "+bnb/grant" do
      let(:enactor) { Fabricate(:character) }
      let(:client) { double(emit_success: nil, emit_failure: nil) }

      def handler(args)
        cmd = double(switch: "grant", args: args)
        h = Soul::SoulBnbCmd.new(client, cmd, enactor)
        h.parse_args
        h
      end

      it "parses character/id-or-tag/level/skills=explanation" do
        h = handler("Alice/cursed/major/blade,spirit=Cursed by a witch.")
        expect(h.name).to eq("Alice")
        expect(h.reference).to eq("cursed")
        expect(h.level).to eq("major")
        expect(h.skill_associations).to eq(["blade", "spirit"])
        expect(h.explanation).to eq("Cursed by a witch.")
      end

      it "defaults level to minor and Skills to empty when both are omitted" do
        h = handler("Alice/cursed=Cursed by a witch.")
        expect(h.level).to eq("minor")
        expect(h.skill_associations).to eq([])
      end

      it "passes a presence-checked Skill list through to SoulBnbApi.grant" do
        target = Fabricate(:character)
        h = handler("Alice/cursed/minor/blade=Cursed by a witch.")
        expect(SoulBnbApi).to receive(:grant).with(
          target, "cursed", level_state: "minor", source: "admin",
          explanation: "Cursed by a witch.", enactor: enactor, associated_skills: ["blade"]
        ).and_return(success: true)

        h.grant_entry(target)
      end
    end

    describe "+bnb/request" do
      let(:enactor) { Fabricate(:character) }
      let(:client) { double(emit_success: nil, emit_failure: nil) }

      def handler(args)
        cmd = double(switch: "request", args: args)
        h = Soul::SoulBnbCmd.new(client, cmd, enactor)
        h.parse_args
        h
      end

      it "parses <id or tag>/<level>/<skills>=<explanation>" do
        h = handler("cursed/major/blade=I want this.")
        expect(h.reference).to eq("cursed")
        expect(h.level).to eq("major")
        expect(h.skill_associations).to eq(["blade"])
        expect(h.explanation).to eq("I want this.")
      end

      it "defaults level to minor when omitted" do
        h = handler("cursed=I want this.")
        expect(h.level).to eq("minor")
      end

      it "requires play permission, not manage_soul" do
        cmd = double(switch: "request", args: "cursed=x")
        h = Soul::SoulBnbCmd.new(client, cmd, enactor)
        allow(Soul).to receive(:can_play?).and_return(false)
        expect(h.check_permission).to be_present
      end

      it "passes through to SoulBnbApi.request scoped to the enactor" do
        h = handler("cursed=I want this.")
        expect(SoulBnbApi).to receive(:request).with(
          enactor, "cursed", explanation: "I want this.", level_state: "minor", associated_skills: nil
        ).and_return(success: true)

        h.request_entry
      end
    end

    describe "+bnb/approve and +bnb/deny" do
      let(:enactor) { Fabricate(:character) }
      let(:client) { double(emit_success: nil, emit_failure: nil) }

      it "requires manage_soul permission" do
        cmd = double(switch: "approve", args: "5")
        h = Soul::SoulBnbCmd.new(client, cmd, enactor)
        allow(Soul).to receive(:can_manage_soul?).and_return(false)
        expect(h.check_permission).to be_present
      end

      it "approve_request_entry passes through to SoulBnbApi.approve_request" do
        cmd = double(switch: "approve", args: "5")
        h = Soul::SoulBnbCmd.new(client, cmd, enactor)
        h.parse_args
        expect(SoulBnbApi).to receive(:approve_request).with(5, enactor).and_return(success: true)
        h.approve_request_entry
      end

      it "deny_request_entry parses <id>=<reason> and passes through" do
        cmd = double(switch: "deny", args: "5=Not appropriate.")
        h = Soul::SoulBnbCmd.new(client, cmd, enactor)
        h.parse_args
        expect(h.request_id).to eq(5)
        expect(h.reason).to eq("Not appropriate.")
        expect(SoulBnbApi).to receive(:deny_request).with(5, enactor, reason: "Not appropriate.")
          .and_return(success: true)
        h.deny_request_entry
      end
    end
  end
end

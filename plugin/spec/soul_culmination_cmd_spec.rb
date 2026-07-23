require_relative 'spec_helper'

module AresMUSH
  describe Soul::SoulCulminationCmd do
    it "is registered for +culmination" do
      cmd = double(root: "culmination")
      expect(Soul.get_cmd_handler(nil, cmd, nil)).to eq(Soul::SoulCulminationCmd)
    end
  end
end

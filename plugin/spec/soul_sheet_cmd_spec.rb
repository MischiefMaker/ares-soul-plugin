require_relative 'spec_helper'

module AresMUSH
  describe Soul::SoulSheetCmd do
    it "is registered for +soul" do
      cmd = double(root: "soul", switch: nil)
      expect(Soul.get_cmd_handler(nil, cmd, nil)).to eq(Soul::SoulSheetCmd)
    end
  end
end

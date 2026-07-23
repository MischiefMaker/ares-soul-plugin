require_relative 'spec_helper'

module AresMUSH
  describe Soul::SoulHistoryCmd do
    it "is registered for +soul/history" do
      cmd = double(root: "soul", switch: "history")
      expect(Soul.get_cmd_handler(nil, cmd, nil)).to eq(Soul::SoulHistoryCmd)
    end
  end
end

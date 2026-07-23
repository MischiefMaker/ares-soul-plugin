require_relative 'spec_helper'

module AresMUSH
  describe Soul::SoulBnbCmd do
    it "is registered for +bnb" do
      cmd = double(root: "bnb")
      expect(Soul.get_cmd_handler(nil, cmd, nil)).to eq(Soul::SoulBnbCmd)
    end
  end
end

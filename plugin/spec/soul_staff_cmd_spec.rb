require_relative 'spec_helper'

module AresMUSH
  describe Soul::SoulStaffCmd do
    it "is registered for +soul/framework" do
      cmd = double(root: "soul", switch: "framework")
      expect(Soul.get_cmd_handler(nil, cmd, nil)).to eq(Soul::SoulStaffCmd)
    end

    it "is registered for +soul/audit" do
      cmd = double(root: "soul", switch: "audit")
      expect(Soul.get_cmd_handler(nil, cmd, nil)).to eq(Soul::SoulStaffCmd)
    end

    it "rejects audit access without management permission" do
      allow(subject).to receive(:enactor).and_return(Fabricate(:character))
      allow(Soul).to receive(:can_manage_soul?).and_return(false)
      expect(subject.check_permission).to be_present
    end
  end
end

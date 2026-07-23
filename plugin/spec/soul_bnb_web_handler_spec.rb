require_relative 'spec_helper'

module AresMUSH
  describe SoulBnbWebHandler do
    it "rechecks staff permission for catalogue creation" do
      request = double(cmd: "soulBnbCreate", enactor: Fabricate(:character), args: {})
      allow(Website).to receive(:check_login).and_return(nil)
      allow(Soul).to receive(:can_manage_soul?).and_return(false)
      expect(subject.handle(request)[:error]).to be_present
    end
  end
end

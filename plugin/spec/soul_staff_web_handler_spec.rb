require_relative 'spec_helper'

module AresMUSH
  describe SoulStaffWebHandler do
    it "rechecks management permission" do
      request = double(enactor: Fabricate(:character))
      allow(Website).to receive(:check_login).and_return(nil)
      allow(Soul).to receive(:can_manage_soul?).and_return(false)
      expect(subject.handle(request)[:error]).to be_present
    end
  end
end

require_relative 'spec_helper'

module AresMUSH
  describe SoulCulminationWebHandler do
    it "rejects unauthenticated requests" do
      request = double
      allow(Website).to receive(:check_login).and_return({ error: "login" })
      expect(subject.handle(request)).to eq({ error: "login" })
    end
  end
end

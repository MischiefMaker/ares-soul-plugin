require_relative 'spec_helper'

module AresMUSH
  describe Soul::SoulDiceEngine do
    describe ".roll" do
      it "returns a total, mode, and segments" do
        result = Soul::SoulDiceEngine.roll(0)
        expect(result[:total]).to be_a(Integer)
        expect([:normal, :explosion, :implosion]).to include(result[:mode])
        expect(result[:segments]).to be_an(Array)
      end

      it "never returns a bare double-20 as the final total with no modifier (explosion always continues)" do
        200.times do
          result = Soul::SoulDiceEngine.roll(0)
          expect(result[:total]).not_to eq(40) if result[:mode] == :explosion && result[:segments].length == 1
        end
      end

      it "does not infinite-loop on an extreme boon modifier" do
        expect { Soul::SoulDiceEngine.roll(50) }.not_to raise_error
      end

      it "does not infinite-loop on an extreme bane modifier" do
        expect { Soul::SoulDiceEngine.roll(-50) }.not_to raise_error
      end

      it "keeps every segment die within 1..20" do
        50.times do
          result = Soul::SoulDiceEngine.roll(3)
          result[:segments].each do |seg|
            expect(seg[:d1]).to be_between(1, 20)
            expect(seg[:d2]).to be_between(1, 20)
          end
        end
      end
    end

    describe ".total_pmf" do
      it "sums to 1.0 with no modifier" do
        pmf = Soul::SoulDiceEngine.total_pmf(0, 12)
        expect(pmf.values.sum).to be_within(1e-9).of(1.0)
      end

      it "sums to 1.0 with a positive (Boon) modifier" do
        pmf = Soul::SoulDiceEngine.total_pmf(5, 10)
        expect(pmf.values.sum).to be_within(1e-6).of(1.0)
      end

      it "sums to 1.0 with a negative (Bane) modifier" do
        pmf = Soul::SoulDiceEngine.total_pmf(-5, 10)
        expect(pmf.values.sum).to be_within(1e-6).of(1.0)
      end

      it "assigns zero probability to a bare double-20 total with no modifier" do
        pmf = Soul::SoulDiceEngine.total_pmf(0, 12)
        expect(pmf[40].to_f).to eq(0.0)
      end
    end

    describe ".success_probability" do
      it "is deterministic across repeated calls with identical inputs" do
        a = Soul::SoulDiceEngine.success_probability(2, 20)
        b = Soul::SoulDiceEngine.success_probability(2, 20)
        expect(a).to eq(b)
      end

      it "increases with a positive (Boon) modifier relative to no modifier" do
        baseline = Soul::SoulDiceEngine.success_probability(0, 20)
        boosted = Soul::SoulDiceEngine.success_probability(5, 20)
        expect(boosted).to be > baseline
      end

      it "decreases with a negative (Bane) modifier relative to no modifier" do
        baseline = Soul::SoulDiceEngine.success_probability(0, 20)
        hindered = Soul::SoulDiceEngine.success_probability(-5, 20)
        expect(hindered).to be < baseline
      end

      it "matches Monte Carlo simulation within tolerance for a standard-difficulty target" do
        analytical = Soul::SoulDiceEngine.success_probability(0, 13)
        trials = 50_000
        successes = trials.times.count { Soul::SoulDiceEngine.roll(0)[:total] >= 13 }
        empirical = successes.to_f / trials
        expect(analytical).to be_within(0.02).of(empirical)
      end

      it "returns 1.0 for a trivially low target" do
        expect(Soul::SoulDiceEngine.success_probability(0, 2)).to be_within(1e-9).of(1.0)
      end

      it "returns a value near the extraordinary threshold at extreme targets" do
        probability = Soul::SoulDiceEngine.success_probability(0, 100)
        expect(probability).to be < 0.0001
        expect(probability).to be >= 0.0
      end
    end
  end
end

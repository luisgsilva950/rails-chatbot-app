require "rails_helper"

RSpec.describe Weather::Mock do
  describe ".fetch" do
    it "returns the entry for a known date (Date input)" do
      expect(described_class.fetch(Date.new(2026, 5, 3))).to include(condition: "sunny")
    end

    it "returns the entry for a known date (string input)" do
      expect(described_class.fetch("2026-04-22")).to include(condition: "storm", precipitation_mm: 42)
    end

    it "returns nil for dates not in the mock" do
      expect(described_class.fetch("2026-04-26")).to be_nil
    end
  end

  describe ".range" do
    it "returns mocked days inside the inclusive range, sorted DESC by date" do
      result = described_class.range("2026-05-01", "2026-05-03")

      expect(result.map { |day| day[:date] }).to eq(%w[2026-05-03 2026-05-02 2026-05-01])
      expect(result.first).to include(condition: "sunny", date: "2026-05-03")
    end

    it "skips dates that are not in the mock" do
      result = described_class.range("2026-04-25", "2026-04-27")

      expect(result.map { |day| day[:date] }).to eq(%w[2026-04-27 2026-04-25])
    end

    it "raises Date::Error for malformed input" do
      expect { described_class.range("nope", "2026-05-01") }.to raise_error(Date::Error)
    end
  end
end

require "rails_helper"

RSpec.describe Weather::ForecastTool do
  let(:tool) { described_class.new }

  it "returns weather data for a single day when end_date is omitted" do
    result = tool.execute(start_date: "2026-05-03")

    expect(result[:start_date]).to eq("2026-05-03")
    expect(result[:end_date]).to   eq("2026-05-03")
    expect(result[:days]).to eq([
      { date: "2026-05-03", condition: "sunny", temperature_c: 28, precipitation_mm: 0 }
    ])
  end

  it "returns weather data across an inclusive range" do
    result = tool.execute(start_date: "2026-04-29", end_date: "2026-05-01")

    expect(result[:days].map { |d| d[:date] }).to eq(%w[2026-05-01 2026-04-30 2026-04-29])
  end

  it "returns an error for invalid input" do
    expect(tool.execute(start_date: "bad")).to eq(error: "Invalid date. Use YYYY-MM-DD.")
  end
end

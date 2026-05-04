require "rails_helper"

RSpec.describe CashFlow::SalesDaysTool do
  before { travel_to Time.zone.local(2026, 5, 3, 14, 0, 0) }
  after  { travel_back }

  let(:tool) { described_class.new }

  it "groups paid payments by day inside the default 30-day window" do
    create(:payment, paid_at: Time.zone.local(2026, 5, 3, 10), amount_cents: 10_000)
    create(:payment, paid_at: Time.zone.local(2026, 5, 3, 18), amount_cents:  5_000)
    create(:payment, paid_at: Time.zone.local(2026, 5, 1,  9), amount_cents: 20_000)

    result = tool.execute

    expect(result[:start_date]).to eq("2026-04-03")
    expect(result[:end_date]).to   eq("2026-05-03")
    expect(result[:days]).to eq([
      { date: "2026-05-03", total_brl: 150.0, count: 2 },
      { date: "2026-05-01", total_brl: 200.0, count: 1 }
    ])
  end

  it "respects a custom range and limit, ignoring unpaid payments and out-of-range days" do
    create(:payment, paid_at: Time.zone.local(2026, 4, 28, 10), amount_cents: 1_000)
    create(:payment, paid_at: Time.zone.local(2026, 4, 29, 10), amount_cents: 2_000)
    create(:payment, paid_at: Time.zone.local(2026, 4, 30, 10), amount_cents: 3_000)
    create(:payment, paid_at: Time.zone.local(2026, 4, 30, 12), amount_cents: 4_000, status: "pending")
    create(:payment, paid_at: Time.zone.local(2026, 5,  2, 10), amount_cents: 9_000)

    result = tool.execute(start_date: "2026-04-29", end_date: "2026-04-30", limit: 1)

    expect(result[:days]).to eq([
      { date: "2026-04-30", total_brl: 30.0, count: 1 }
    ])
  end

  it "returns an error for invalid dates" do
    expect(tool.execute(start_date: "bad")).to eq(error: "Invalid date. Use YYYY-MM-DD.")
  end
end

require "rails_helper"

RSpec.describe CashFlow::DailyRevenueTool do
  before { travel_to Time.zone.local(2026, 5, 3, 14, 0, 0) }
  after  { travel_back }

  let(:tool) { described_class.new }

  it "totals payments for today and breaks down by payment method" do
    create(:payment, paid_at: Time.current,           amount_cents: 10_000, payment_method: "pix")
    create(:payment, paid_at: Time.current,           amount_cents:  5_000, payment_method: "credit")
    create(:payment, paid_at: Time.current - 2.days,  amount_cents: 99_999, payment_method: "pix")

    result = tool.execute

    expect(result).to include(
      date:      "2026-05-03",
      total_brl: 150.0,
      count:     2,
      by_method: { "pix" => 100.0, "credit" => 50.0 }
    )
  end

  it "accepts a custom date" do
    create(:payment, paid_at: Time.zone.local(2026, 5, 1, 10), amount_cents: 4_000, payment_method: "cash")

    result = tool.execute(date: "2026-05-01")

    expect(result).to include(date: "2026-05-01", total_brl: 40.0, by_method: { "cash" => 40.0 })
  end

  it "returns an error for invalid dates" do
    expect(tool.execute(date: "bad")).to eq(error: "Invalid date. Use YYYY-MM-DD.")
  end
end

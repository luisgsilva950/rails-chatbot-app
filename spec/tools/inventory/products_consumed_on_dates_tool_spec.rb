require "rails_helper"

RSpec.describe Inventory::ProductsConsumedOnDatesTool do
  let(:tool) { described_class.new }

  it "returns one bucket per requested date with products and quantity_out summed across the day" do
    shampoo = create(:product, name: "Shampoo Neutro", category: "shampoo", unit: "l")
    wax     = create(:product, name: "Cera Líquida",   category: "wax",     unit: "ml")
    create(:stock_movement, product: shampoo, kind: "out", quantity: 2, occurred_at: Time.zone.local(2026, 4, 12, 10))
    create(:stock_movement, product: shampoo, kind: "out", quantity: 3, occurred_at: Time.zone.local(2026, 4, 12, 18))
    create(:stock_movement, product: wax,     kind: "out", quantity: 1, occurred_at: Time.zone.local(2026, 4, 19, 14))

    result = tool.execute(dates: [ "2026-04-19", "2026-04-12" ])

    expect(result).to eq(
      dates: [
        { date: "2026-04-12", products: [ { sku: shampoo.sku, name: "Shampoo Neutro", category: "shampoo", unit: "l",  quantity_out: 5 } ] },
        { date: "2026-04-19", products: [ { sku: wax.sku,     name: "Cera Líquida",   category: "wax",     unit: "ml", quantity_out: 1 } ] }
      ]
    )
  end

  it "returns an empty bucket for dates without out-movements and ignores other kinds and other days" do
    product = create(:product)
    create(:stock_movement, product: product, kind: "in",  quantity: 5, occurred_at: Time.zone.local(2026, 4, 12, 10))
    create(:stock_movement, product: product, kind: "out", quantity: 2, occurred_at: Time.zone.local(2026, 4, 11, 23, 59))

    result = tool.execute(dates: [ "2026-04-12" ])

    expect(result).to eq(dates: [ { date: "2026-04-12", products: [] } ])
  end

  it "deduplicates and sorts the requested dates" do
    product = create(:product)
    create(:stock_movement, product: product, kind: "out", quantity: 1, occurred_at: Time.zone.local(2026, 4, 12, 10))

    result = tool.execute(dates: [ "2026-04-15", "2026-04-12", "2026-04-12" ])

    expect(result[:dates].map { |bucket| bucket[:date] }).to eq([ "2026-04-12", "2026-04-15" ])
  end

  it "errors when no dates are provided" do
    expect(tool.execute(dates: [])).to eq(error: "Provide at least one date.")
    expect(tool.execute(dates: [ "" ])).to eq(error: "Provide at least one date.")
  end

  it "errors when more than the cap of dates is provided" do
    too_many = (1..32).map { |i| Date.new(2026, 4, 1).advance(days: i).iso8601 }

    expect(tool.execute(dates: too_many)).to eq(error: "Too many dates (max 31).")
  end

  it "errors on malformed dates" do
    expect(tool.execute(dates: [ "not-a-date" ])).to eq(error: "Invalid date. Use YYYY-MM-DD.")
  end
end

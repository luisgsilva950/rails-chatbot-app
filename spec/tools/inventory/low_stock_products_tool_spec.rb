require "rails_helper"

RSpec.describe Inventory::LowStockProductsTool do
  let(:tool) { described_class.new }

  it "lists products below the minimum stock" do
    low  = create(:product, stock_quantity: 1, min_stock: 3, category: "shampoo")
    create(:product, stock_quantity: 10, min_stock: 3)

    result = tool.execute

    expect(result.map { |row| row[:sku] }).to eq([ low.sku ])
  end

  it "filters by category when provided" do
    create(:product, stock_quantity: 1, min_stock: 3, category: "shampoo")
    polish_low = create(:product, stock_quantity: 0, min_stock: 1, category: "polish")

    result = tool.execute(category: "polish")

    expect(result.map { |row| row[:sku] }).to eq([ polish_low.sku ])
  end
end

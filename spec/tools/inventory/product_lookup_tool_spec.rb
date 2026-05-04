require "rails_helper"

RSpec.describe Inventory::ProductLookupTool do
  let(:tool) { described_class.new }

  it "finds products by partial name" do
    product = create(:product, name: "Shampoo Neutro 5L")

    result = tool.execute(query: "neutro")

    expect(result.map { |row| row[:sku] }).to eq([ product.sku ])
  end

  it "returns an error when query is blank" do
    expect(tool.execute(query: "  ")).to eq(error: "Provide a search term.")
  end
end

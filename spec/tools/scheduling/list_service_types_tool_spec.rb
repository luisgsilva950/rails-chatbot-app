require "rails_helper"

RSpec.describe Scheduling::ListServiceTypesTool do
  let(:tool) { described_class.new }

  it "returns the whole catalog ordered by name, with duration and price" do
    create(:service_type, name: "Polimento", category: "detailing", duration_minutes: 180, price_cents: 35_000)
    create(:service_type, name: "Lavagem Simples", category: "wash", duration_minutes: 40, price_cents: 4_500)

    result = tool.execute

    expect(result.map { |row| row[:name] }).to eq([ "Lavagem Simples", "Polimento" ])
    expect(result.first).to include(category: "wash", duration_minutes: 40, price_brl: 45.0)
  end

  it "filters by category" do
    create(:service_type, name: "Lavagem Simples", category: "wash")
    create(:service_type, name: "Polimento", category: "detailing")

    result = tool.execute(category: "detailing")

    expect(result.map { |row| row[:name] }).to eq([ "Polimento" ])
  end
end

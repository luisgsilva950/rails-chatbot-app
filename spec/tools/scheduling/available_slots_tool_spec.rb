require "rails_helper"

RSpec.describe Scheduling::AvailableSlotsTool do
  let(:tool)    { described_class.new }
  let(:service) { create(:service_type, name: "Lavagem Simples", duration_minutes: 40) }
  let(:monday)  { Date.current.next_occurring(:monday) }

  it "reports the free start times for the service on that date" do
    create(:employee)

    result = tool.execute(date: monday.iso8601, service_type_id: service.id)

    expect(result).to include(date: monday.iso8601, service: "Lavagem Simples", duration_minutes: 40)
    expect(result[:available_starts]).to include("08:00", "17:30")
  end

  it "returns an empty list when the shop is closed that day" do
    sunday = Date.current.next_occurring(:sunday)

    result = tool.execute(date: sunday.iso8601, service_type_id: service.id)

    expect(result[:available_starts]).to be_empty
  end

  it "explains how to recover from an unknown service id" do
    result = tool.execute(date: monday.iso8601, service_type_id: 0)

    expect(result[:error]).to match(/list_service_types/)
  end

  it "rejects a malformed date" do
    result = tool.execute(date: "07/08/2026", service_type_id: service.id)

    expect(result[:error]).to match(/YYYY-MM-DD/)
  end
end

require "rails_helper"

RSpec.describe Scheduling::ListAppointmentsForDateTool do
  before { travel_to Time.zone.local(2026, 5, 3, 10, 0, 0) }
  after  { travel_back }

  let(:tool) { described_class.new }

  it "returns serialized appointments for today by default" do
    appointment = create(:appointment, scheduled_at: Time.current + 1.hour, status: "scheduled")

    result = tool.execute

    expect(result.size).to eq(1)
    payload = result.first
    expect(payload).to include(
      id:       appointment.id,
      status:   "scheduled",
      service:  appointment.service_type.name,
      total_brl: 89.0
    )
  end

  it "filters by status when provided" do
    create(:appointment, scheduled_at: Time.current + 1.hour, status: "scheduled")
    completed = create(:appointment, scheduled_at: Time.current + 2.hours, status: "completed")

    result = tool.execute(date: "2026-05-03", status: "completed")

    expect(result.map { |row| row[:id] }).to eq([ completed.id ])
  end

  it "returns an error for invalid dates" do
    expect(tool.execute(date: "not-a-date")).to eq(error: "Data inválida. Use o formato AAAA-MM-DD.")
  end
end

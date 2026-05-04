require "rails_helper"

RSpec.describe Scheduling::UpcomingAppointmentsTool do
  let(:tool) { described_class.new }

  it "returns upcoming appointments with default limit" do
    upcoming = create(:appointment, scheduled_at: Time.current + 1.day, status: "scheduled")
    create(:appointment, scheduled_at: Time.current - 1.day, status: "completed")

    result = tool.execute

    expect(result.map { |row| row[:id] }).to eq([ upcoming.id ])
  end

  it "clamps the limit to the allowed range" do
    3.times { |i| create(:appointment, scheduled_at: Time.current + (i + 1).days, status: "scheduled") }

    expect(tool.execute(limit: 1).size).to eq(1)
    expect(tool.execute(limit: 999).size).to eq(3)
  end
end

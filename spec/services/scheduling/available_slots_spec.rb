require "rails_helper"

RSpec.describe Scheduling::AvailableSlots do
  let(:service)  { create(:service_type, duration_minutes: 60) }
  let(:monday)   { Date.current.next_occurring(:monday) }
  let(:sunday)   { Date.current.next_occurring(:sunday) }

  def starts_on(date, capacity: 1)
    described_class.new(capacity: capacity).call(date, service).map { |start| start.strftime("%H:%M") }
  end

  it "offers every opening-hours start when the agenda is empty" do
    expect(starts_on(monday)).to start_with("08:00", "08:30").and end_with("17:30")
  end

  it "drops the starts whose service would overlap a booked appointment" do
    booked = create(:service_type, duration_minutes: 60)
    create(:appointment, service_type: booked, scheduled_at: monday.in_time_zone.change(hour: 10))

    expect(starts_on(monday)).not_to include("09:30", "10:00", "10:30")
    expect(starts_on(monday)).to include("09:00", "11:00")
  end

  it "keeps a start available while the shop still has a free hand" do
    booked = create(:service_type, duration_minutes: 60)
    create(:appointment, service_type: booked, scheduled_at: monday.in_time_zone.change(hour: 10))

    expect(starts_on(monday, capacity: 2)).to include("10:00")
  end

  it "ignores canceled and no-show appointments" do
    booked = create(:service_type, duration_minutes: 60)
    create(:appointment, service_type: booked, scheduled_at: monday.in_time_zone.change(hour: 10), status: "canceled")
    create(:appointment, service_type: booked, scheduled_at: monday.in_time_zone.change(hour: 11), status: "no_show")

    expect(starts_on(monday)).to include("10:00", "11:00")
  end

  it "counts appointments that run at the same moment, not every one it spans" do
    short = create(:service_type, duration_minutes: 30)
    long  = create(:service_type, duration_minutes: 240)
    # Four back-to-back half-hour jobs: never more than one at a time, so a
    # single free hand is enough to take the long service alongside them.
    [ 9, 10, 11, 12 ].each do |hour|
      create(:appointment, service_type: short, scheduled_at: monday.in_time_zone.change(hour: hour))
    end

    starts = described_class.new(capacity: 2).call(monday, long).map { |s| s.strftime("%H:%M") }

    expect(starts).to include("09:00")
  end

  it "returns nothing on Sunday, when the shop is closed" do
    expect(starts_on(sunday)).to be_empty
  end

  it "returns nothing for a date already past" do
    expect(starts_on(Date.current - 1)).to be_empty
  end

  it "defaults its capacity to the number of employees" do
    booked = create(:service_type, duration_minutes: 60)
    # The appointment factory brings its own employee, so the shop has exactly
    # one hand here and that hand is busy at 10:00.
    create(:appointment, service_type: booked, scheduled_at: monday.in_time_zone.change(hour: 10))
    default_starts = -> { described_class.new.call(monday, service).map { |start| start.strftime("%H:%M") } }

    expect(default_starts.call).not_to include("10:00")
    expect { create(:employee) }.to change { default_starts.call.include?("10:00") }.from(false).to(true)
  end
end

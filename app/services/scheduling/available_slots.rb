# Works out which start times a service could still take on a given date.
# The shop runs several jobs at once — one per employee — so a start is
# free while fewer than that many booked appointments overlap it.
#
# This is a read-only view of the agenda: nothing here books anything.
class Scheduling::AvailableSlots
  OPENS_AT          = 8
  LAST_START_HOUR   = 17
  STEP_MINUTES      = 30
  CLOSED_WDAYS      = [ 0 ].freeze # Sunday
  BLOCKING_STATUSES = %w[scheduled in_progress].freeze

  def initialize(capacity: Employee.count)
    @capacity = capacity
  end

  def call(date, service_type)
    return [] if CLOSED_WDAYS.include?(date.wday)

    busy = busy_intervals(date)
    candidates(date).select { |start| free?(start, service_type.duration_minutes, busy) }
  end

  private

  def candidates(date)
    (OPENS_AT..LAST_START_HOUR).flat_map { |hour| starts_within(date, hour) }.select(&:future?)
  end

  def starts_within(date, hour)
    (0...60).step(STEP_MINUTES).map { |minute| Time.zone.local(date.year, date.month, date.day, hour, minute) }
  end

  def busy_intervals(date)
    Appointment.on_date(date).where(status: BLOCKING_STATUSES).includes(:service_type).map { |a| interval(a) }
  end

  def interval(appointment)
    start = appointment.scheduled_at
    [ start, start + appointment.service_type.duration_minutes.minutes ]
  end

  def free?(start, duration_minutes, busy)
    finish = start + duration_minutes.minutes
    peak_load(busy.select { |s, e| s < finish && start < e }, start, finish) < @capacity
  end

  # One hand has to stay free for the whole job, so what matters is how many
  # appointments run at the same moment inside the window — not how many
  # touch it. A long service spans many short jobs that never overlap each
  # other, and counting those would wrongly report the day as full. Peak
  # load can only change where an appointment starts.
  def peak_load(overlapping, start, finish)
    moments = [ start ] + overlapping.map(&:first).select { |s| s > start && s < finish }
    moments.map { |moment| overlapping.count { |s, e| s <= moment && moment < e } }.max
  end
end

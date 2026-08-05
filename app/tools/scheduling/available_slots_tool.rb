class Scheduling::AvailableSlotsTool < RubyLLM::Tool
  description "Returns the start times still free for one service on one date — the actual answer to \"what times do you have?\". The shop handles several cars at once, so a time is free while it still has a free hand for the whole duration of that service. An empty list means genuinely nothing free that day; the shop is closed on Sundays. This reports availability only — it does not book anything."

  params do
    string :date, description: "Date in YYYY-MM-DD format."
    integer :service_type_id,
            description: "Id of the service, as returned by scheduling--list_service_types. Call that tool first if you do not have it."
  end

  def execute(date:, service_type_id:)
    target  = Date.iso8601(date)
    service = ServiceType.find_by(id: service_type_id)
    return { error: "Unknown service_type_id. Call scheduling--list_service_types first." } unless service

    serialize(target, service)
  rescue Date::Error
    { error: "Invalid date. Use YYYY-MM-DD." }
  end

  private

  def serialize(date, service)
    starts = Scheduling::AvailableSlots.new.call(date, service)
    {
      date:             date.iso8601,
      service:          service.name,
      duration_minutes: service.duration_minutes,
      available_starts: starts.map { |start| start.strftime("%H:%M") }
    }
  end
end

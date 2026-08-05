class Scheduling::UpcomingAppointmentsTool < RubyLLM::Tool
  description "Returns the next appointments ALREADY BOOKED (status scheduled or in_progress), soonest first, across all dates. These are taken slots, not free ones — this is not an availability check. Use it for questions like what is coming up next or what the shop's agenda looks like from now on."

  params do
    integer :limit, required: false,
            description: "How many appointments to return. Default: 10. Max: 50."
  end

  def execute(limit: 10)
    capped = limit.to_i.clamp(1, 50)
    Appointment.upcoming.includes(:customer, :vehicle, :service_type).limit(capped).map do |appointment|
      {
        id:           appointment.id,
        scheduled_at: appointment.scheduled_at.iso8601,
        status:       appointment.status,
        customer:     appointment.customer.name,
        service:      appointment.service_type.name,
        vehicle:      appointment.vehicle.plate
      }
    end
  end
end

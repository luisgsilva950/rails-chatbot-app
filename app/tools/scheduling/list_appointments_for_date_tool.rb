class Scheduling::ListAppointmentsForDateTool < RubyLLM::Tool
  description "Lists detailing-shop appointments for a specific date."

  params do
    string :date, description: "Date in YYYY-MM-DD format. Defaults to today."
    string :status, required: false,
           enum: %w[scheduled in_progress completed canceled no_show],
           description: "Filter by status. Empty returns all."
  end

  def execute(date: nil, status: nil)
    target = parse_date(date)
    scope  = Appointment.on_date(target).includes(:customer, :vehicle, :service_type)
    scope  = scope.where(status: status) if status.present?
    scope.order(:scheduled_at).map { |appointment| serialize(appointment) }
  rescue Date::Error
    { error: "Invalid date. Use YYYY-MM-DD." }
  end

  private

  def parse_date(value)
    value.present? ? Date.iso8601(value) : Time.zone.today
  end

  def serialize(appointment)
    {
      id:           appointment.id,
      scheduled_at: appointment.scheduled_at.iso8601,
      status:       appointment.status,
      customer:     appointment.customer.name,
      vehicle:      "#{appointment.vehicle.brand} #{appointment.vehicle.model} (#{appointment.vehicle.plate})",
      service:      appointment.service_type.name,
      total_brl:    appointment.total_cents / 100.0
    }
  end
end

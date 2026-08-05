class Scheduling::ListServiceTypesTool < RubyLLM::Tool
  description "Lists the services the shop actually offers, with duration and price. This is the authoritative catalog — call it before naming, listing, pricing, or confirming any service, and never invent or guess a service name."

  params do
    string :category, required: false,
           enum: ServiceType::CATEGORIES,
           description: "Filter by category (wash, detailing, protection, interior). Empty returns the whole catalog."
  end

  def execute(category: nil)
    scope = ServiceType.all
    scope = scope.where(category: category) if category.present?
    scope.order(:name).map { |service_type| serialize(service_type) }
  end

  private

  def serialize(service_type)
    {
      id:               service_type.id,
      name:             service_type.name,
      category:         service_type.category,
      duration_minutes: service_type.duration_minutes,
      price_brl:        service_type.price_cents / 100.0
    }
  end
end

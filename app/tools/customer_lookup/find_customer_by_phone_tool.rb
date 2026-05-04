class CustomerLookup::FindCustomerByPhoneTool < RubyLLM::Tool
  description "Finds a customer by phone number and returns their registered vehicles."

  params do
    string :phone, description: "Customer phone. Partial input is accepted: digits are extracted before searching."
  end

  def execute(phone:)
    digits = phone.to_s.gsub(/\D/, "")
    return { error: "Provide a valid phone number." } if digits.empty?

    customer = Customer.where("REGEXP_REPLACE(phone, '\\D', '', 'g') ILIKE ?", "%#{digits}%").first
    return { error: "No customer found for that phone number." } unless customer

    {
      id:       customer.id,
      name:     customer.name,
      phone:    customer.phone,
      email:    customer.email,
      vehicles: customer.vehicles.map { |v| { plate: v.plate, brand: v.brand, model: v.model, year: v.year } }
    }
  end
end

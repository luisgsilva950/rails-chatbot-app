class CustomerLookup::FindCustomerByPhoneTool < RubyLLM::Tool
  description "Localiza um cliente pelo telefone e retorna seus veículos cadastrados."

  params do
    string :phone, description: "Telefone do cliente. Aceita parcial: dígitos são extraídos antes da busca."
  end

  def execute(phone:)
    digits = phone.to_s.gsub(/\D/, "")
    return { error: "Informe um telefone válido." } if digits.empty?

    customer = Customer.where("REGEXP_REPLACE(phone, '\\D', '', 'g') ILIKE ?", "%#{digits}%").first
    return { error: "Cliente não encontrado para esse telefone." } unless customer

    {
      id:       customer.id,
      name:     customer.name,
      phone:    customer.phone,
      email:    customer.email,
      vehicles: customer.vehicles.map { |v| { plate: v.plate, brand: v.brand, model: v.model, year: v.year } }
    }
  end
end

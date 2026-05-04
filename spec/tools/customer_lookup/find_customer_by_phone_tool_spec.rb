require "rails_helper"

RSpec.describe CustomerLookup::FindCustomerByPhoneTool do
  let(:tool) { described_class.new }

  it "finds a customer by partial phone digits and returns their vehicles" do
    customer = create(:customer, phone: "(11) 91234-5678")
    create(:vehicle, customer: customer, plate: "AAA1B23")

    result = tool.execute(phone: "12345678")

    expect(result).to include(id: customer.id)
    expect(result[:vehicles].first).to include(plate: "AAA1B23")
  end

  it "returns an error when no digits are provided" do
    expect(tool.execute(phone: "abc")).to eq(error: "Informe um telefone válido.")
  end

  it "returns an error when no customer matches" do
    expect(tool.execute(phone: "0000000")).to eq(error: "Cliente não encontrado para esse telefone.")
  end
end

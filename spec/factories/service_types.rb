FactoryBot.define do
  factory :service_type do
    sequence(:name)  { |n| "Serviço #{n}" }
    category         { "wash" }
    duration_minutes { 60 }
    price_cents      { 8_900 }
  end
end

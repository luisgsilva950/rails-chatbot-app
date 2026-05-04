FactoryBot.define do
  factory :appointment do
    customer
    vehicle      { association :vehicle, customer: customer }
    service_type
    employee
    scheduled_at { Time.current + 1.day }
    status       { "scheduled" }
    total_cents  { 8_900 }
  end
end

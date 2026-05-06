FactoryBot.define do
  factory :stock_movement do
    product
    kind        { "out" }
    quantity    { 1 }
    reason      { "sale" }
    occurred_at { Time.zone.now }
  end
end

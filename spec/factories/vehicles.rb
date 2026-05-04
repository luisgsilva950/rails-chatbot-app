FactoryBot.define do
  factory :vehicle do
    customer
    sequence(:plate) { |n| "ABC#{format('%04d', n)}" }
    brand { "Volkswagen" }
    model { "Gol" }
    year  { 2022 }
    color { "Preto" }
    kind  { "car" }
  end
end

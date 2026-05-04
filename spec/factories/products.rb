FactoryBot.define do
  factory :product do
    sequence(:name) { |n| "Produto #{n}" }
    sequence(:sku)  { |n| "SKU-#{format('%04d', n)}" }
    category        { "shampoo" }
    unit            { "l" }
    stock_quantity  { 10 }
    min_stock       { 2 }
    cost_cents      { 1_000 }
    price_cents     { 2_000 }
  end
end

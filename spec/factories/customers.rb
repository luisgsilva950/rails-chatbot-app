FactoryBot.define do
  factory :customer do
    sequence(:name)  { |n| "Cliente Teste #{n}" }
    sequence(:phone) { |n| "(11) 9#{format('%04d', n)}-1111" }
    sequence(:email) { |n| "cliente#{n}@example.com" }
  end
end

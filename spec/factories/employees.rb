FactoryBot.define do
  factory :employee do
    sequence(:name) { |n| "Funcionário #{n}" }
    role            { "washer" }
    active          { true }
  end
end

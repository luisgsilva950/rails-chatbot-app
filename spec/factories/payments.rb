FactoryBot.define do
  factory :payment do
    appointment
    payment_method { "pix" }
    status         { "paid" }
    amount_cents   { 8_900 }
    paid_at        { Time.current }
  end
end

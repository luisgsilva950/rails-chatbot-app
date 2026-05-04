class CashFlow::DailyRevenueTool < RubyLLM::Tool
  description "Cash-flow summary for a single day: total received and breakdown by payment method."

  params do
    string :date, required: false,
           description: "Date in YYYY-MM-DD format. Defaults to today."
  end

  def execute(date: nil)
    target  = parse_date(date)
    payments = Payment.paid_between(target.all_day)
    total   = payments.sum(:amount_cents)

    {
      date:        target.iso8601,
      total_brl:   total / 100.0,
      count:       payments.count,
      by_method:   breakdown(payments)
    }
  rescue Date::Error
    { error: "Invalid date. Use YYYY-MM-DD." }
  end

  private

  def parse_date(value)
    value.present? ? Date.iso8601(value) : Time.zone.today
  end

  def breakdown(payments)
    payments.group(:payment_method).sum(:amount_cents).transform_values { |cents| cents / 100.0 }
  end
end

class CashFlow::SalesDaysTool < RubyLLM::Tool
  description "Lista os dias em que houve pagamentos confirmados, com total recebido em cada dia. Use quando o usuário perguntar quais dias tiveram vendas, faturamento, recebimentos ou movimento de caixa."

  params do
    string :start_date, required: false,
           description: "Data inicial (AAAA-MM-DD). Padrão: 30 dias atrás."
    string :end_date, required: false,
           description: "Data final (AAAA-MM-DD), inclusiva. Padrão: hoje."
    integer :limit, required: false,
            description: "Máximo de dias retornados. Padrão: 30. Limite: 365."
  end

  def execute(start_date: nil, end_date: nil, limit: nil)
    range = parse_range(start_date, end_date)
    capped = clamp_limit(limit)
    rows = Payment.paid.where(paid_at: range)
                  .group("DATE(paid_at)")
                  .order(Arel.sql("DATE(paid_at) DESC"))
                  .limit(capped)
                  .pluck(Arel.sql("DATE(paid_at)"), Arel.sql("SUM(amount_cents)"), Arel.sql("COUNT(*)"))

    {
      start_date: range.begin.to_date.iso8601,
      end_date:   range.end.to_date.iso8601,
      days:       rows.map { |date, cents, count| { date: date.iso8601, total_brl: cents / 100.0, count: count } }
    }
  rescue Date::Error
    { error: "Data inválida. Use o formato AAAA-MM-DD." }
  end

  private

  def parse_range(start_str, end_str)
    finish = end_str.present?   ? Date.iso8601(end_str)   : Time.zone.today
    start  = start_str.present? ? Date.iso8601(start_str) : (finish - 30)
    start.beginning_of_day..finish.end_of_day
  end

  def clamp_limit(value)
    [ [ Integer(value || 30), 1 ].max, 365 ].min
  end
end

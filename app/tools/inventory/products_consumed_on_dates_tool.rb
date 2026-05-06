class Inventory::ProductsConsumedOnDatesTool < RubyLLM::Tool
  description "Lists products consumed (stock movements with kind='out') on each of a given list of calendar dates. Use to find what was sold/used on specific days — e.g. when crossing top sales days with inventory consumption. Returns a bucket per requested date (empty if no movements)."

  MAX_DATES = 31

  params do
    array :dates, of: :string,
          description: "Calendar dates (YYYY-MM-DD), max 31. Each date is treated as a full local-time day."
  end

  def execute(dates:)
    parsed = parse_dates(dates)
    return parsed if parsed.is_a?(Hash)

    { dates: bucket_by_date(parsed, fetch_rows(parsed)) }
  end

  private

  def parse_dates(input)
    list = Array(input).map(&:to_s).reject(&:blank?).uniq.sort
    return { error: "Provide at least one date." } if list.empty?
    return { error: "Too many dates (max #{MAX_DATES})." } if list.size > MAX_DATES

    list.map { |s| Date.iso8601(s) }
  rescue Date::Error
    { error: "Invalid date. Use YYYY-MM-DD." }
  end

  def fetch_rows(date_objects)
    range = date_objects.min.beginning_of_day..date_objects.max.end_of_day
    StockMovement.where(kind: "out", occurred_at: range).joins(:product)
                 .group(*group_columns)
                 .order(Arel.sql("DATE(stock_movements.occurred_at) ASC, products.name ASC"))
                 .pluck(*pluck_columns)
  end

  def group_columns
    [ Arel.sql("DATE(stock_movements.occurred_at)"),
     "products.sku", "products.name", "products.category", "products.unit" ]
  end

  def pluck_columns
    [ Arel.sql("DATE(stock_movements.occurred_at)"),
     "products.sku", "products.name", "products.category", "products.unit",
     Arel.sql("SUM(stock_movements.quantity)") ]
  end

  def bucket_by_date(dates, rows)
    grouped = rows.group_by(&:first)
    dates.map { |date| { date: date.iso8601, products: format_products(grouped[date] || []) } }
  end

  def format_products(rows)
    rows.map { |_, sku, name, category, unit, qty| { sku: sku, name: name, category: category, unit: unit, quantity_out: qty.to_i } }
  end
end

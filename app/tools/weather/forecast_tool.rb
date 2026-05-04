class Weather::ForecastTool < RubyLLM::Tool
  description "Looks up (mocked) weather data for a date or range, including past, present, and future dates. Returns condition, temperature, and precipitation per day. Also use for historical questions, e.g. 'how was the weather over the last 30 days?'."

  params do
    string :start_date, required: true,
           description: "Start date in YYYY-MM-DD format. May be a past date."
    string :end_date, required: false,
           description: "End date in YYYY-MM-DD format, inclusive. If omitted, uses start_date (single-day lookup)."
  end

  def execute(start_date:, end_date: nil)
    finish = end_date.presence || start_date
    days = Weather::Mock.range(start_date, finish)
    {
      start_date: start_date,
      end_date:   finish,
      days:       days
    }
  rescue Date::Error
    { error: "Invalid date. Use YYYY-MM-DD." }
  end
end

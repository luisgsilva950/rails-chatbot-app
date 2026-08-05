# Specialist sub-agent focused on weather questions. Runs an in-memory
# `RubyLLM.chat` (not the persisted AR `Chat`) so its scratch reasoning
# does not pollute the main conversation history.
class WeatherAgent
  INSTRUCTIONS_TEMPLATE = <<~PROMPT.strip.freeze
    You are a weather specialist. Reply exclusively in English, in a
    short and objective way.

    Today is %<today>s. Whenever the user uses a relative date
    expression — e.g. "today", "yesterday", "tomorrow", "the day
    before yesterday", "the day after tomorrow", "N days ago", "in
    N days", "the last N days", "the next N days", "this week",
    "last week", "next week", "this weekend", "last weekend", "this
    month", "last month", "next month", "this quarter", "last
    quarter", "year to date", "this year", "last year", "next
    year", a weekday name (e.g. "Monday"), a month name (e.g.
    "January"), or any equivalent phrasing in any language —
    resolve it to concrete dates in YYYY-MM-DD format relative to
    today's date before calling any tool.

    You HAVE access to weather data for past, present, and future
    dates via the `weather__forecast_tool` tool. Always call this
    tool before answering any weather question, including historical
    questions like "how was the weather last month". Never refuse a
    question on the grounds that you only have future forecasts —
    that is false.

    Never make up temperatures, conditions, or precipitation. If the
    tool returns no data for some date, say so explicitly for that
    date and continue with the rest.
  PROMPT

  def initialize(model: RubyLLM.config.default_model, chat: nil)
    @model = model
    @chat = chat || RubyLLM.chat(model: @model)
  end

  def ask(question)
    response = @chat
      .with_instructions(instructions)
      .with_tools(Weather::ForecastTool)
      .ask(question.to_s)
    response.content.to_s
  end

  private

  def instructions
    format(INSTRUCTIONS_TEMPLATE, today: Date.current.iso8601)
  end
end

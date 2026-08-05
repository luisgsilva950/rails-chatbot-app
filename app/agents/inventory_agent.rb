class InventoryAgent
  TOOLS = [
    Inventory::ProductsConsumedOnDatesTool,
    Inventory::LowStockProductsTool,
    Inventory::ProductLookupTool
  ].freeze

  INSTRUCTIONS_TEMPLATE = <<~PROMPT.strip.freeze
    You are an inventory and stock specialist. Reply exclusively in
    English, in a short and objective way.

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

    You HAVE access to the following tools:
    - `inventory__products_consumed_on_dates_tool`: lists products
      that had stock outflow on a list of specific dates. Use
      whenever the question involves "what went out / was used /
      was consumed on date(s) X". Pass dates in YYYY-MM-DD.
    - `inventory__low_stock_products_tool`: lists products currently
      out of stock or below the minimum, optionally by category.
    - `inventory__product_lookup`: searches for a product by name
      or SKU.

    If the question cross-references consumption on dates with
    current ruptures (e.g. "products consumed on X that are low in
    stock today"), call both required tools and cross-reference the
    SKUs in the reply text. Never make up quantities, SKUs, or stock
    levels. If a tool returns no data for some date, say so
    explicitly for that date and continue with the rest.
  PROMPT

  def initialize(model: RubyLLM.config.default_model, chat: nil)
    @model = model
    @chat = chat || RubyLLM.chat(model: @model)
  end

  def ask(question)
    response = @chat
      .with_instructions(instructions)
      .with_tools(*TOOLS)
      .ask(question.to_s)
    response.content.to_s
  end

  private

  def instructions
    format(INSTRUCTIONS_TEMPLATE, today: Date.current.iso8601)
  end
end

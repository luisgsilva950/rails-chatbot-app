# Configures the persisted Chat (model, instructions, tools) and runs a
# single assistant turn. `acts_as_chat` is the ruby_llm boundary — there is
# no separate "client" layer, so configuration lives here.
class Chat::Replier
  SYSTEM_INSTRUCTIONS = <<~PROMPT.strip.freeze
    You are the assistant of a car detailing shop. Reply in pt-BR in a
    clear, direct, and objective way. Use the available tools to look up
    appointments, customers, and cash flow before answering questions
    that depend on that data, and delegate inventory questions to the
    `inventory__ask_agent` specialist and weather questions to the
    `weather__ask_agent` specialist. To cross-reference weather or
    inventory with sales/appointments, first determine the relevant days
    via the cash-flow/scheduling tools and then pass those dates, in
    natural language, to the corresponding specialist. Never make up
    numbers, dates, products, or weather conditions.

    Important rules about tool usage:
    - Do not announce that you are going to use a tool — call it
      immediately in the same turn. Phrases like "I will look up",
      "I am searching", or "I will now check" are forbidden if you
      have not actually emitted the tool call in the same turn.
    - If you need data from more than one tool, chain the calls
      without intermediate text. Only write the final reply once you
      have all the data in hand.
    - If a tool fails or has no data, say so clearly in the final
      reply, without promising to "try again".
  PROMPT

  DEFAULT_TOOLS = [
    Scheduling::ListAppointmentsForDateTool,
    Scheduling::UpcomingAppointmentsTool,
    CashFlow::DailyRevenueTool,
    CashFlow::SalesDaysTool,
    CustomerLookup::FindCustomerByPhoneTool,
    Inventory::AskAgentTool,
    Weather::AskAgentTool
  ].freeze

  # Token budget for the model's thinking phase. Enabling it also sends
  # `includeThoughts`, so thought summaries stream back on Chunk#thinking
  # and are persisted by acts_as_chat in Message#thinking_text.
  THINKING_BUDGET = 2048

  def initialize(tools: DEFAULT_TOOLS, model: RubyLLM.config.default_model)
    @tools = tools
    @model = model
  end

  def call(chat, on_tool_call: nil, &on_chunk)
    return unless chat.messages.where(role: "user").exists?

    chat.on_tool_call(&on_tool_call) if on_tool_call
    chat
      .with_model(@model)
      .with_instructions(SYSTEM_INSTRUCTIONS)
      .with_tools(*@tools)
      .with_thinking(budget: THINKING_BUDGET)
      .complete(&on_chunk)
  end
end

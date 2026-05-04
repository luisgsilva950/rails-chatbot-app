# Agent-as-a-tool wrapper. Lets the main chat delegate weather questions
# to the focused `WeatherAgent` sub-agent. The orchestrator (main chat)
# only sees a single tool call with the natural-language answer — the
# sub-agent's reasoning and intermediate tool calls stay isolated.
class Weather::AskAgentTool < RubyLLM::Tool
  description "Asks the weather specialist. Use whenever the question involves weather, meteorological conditions, rain, or temperature — for past, present, or future dates, including when crossing weather with sales or appointments. Pass the full question in natural language; the specialist handles fetching data for the relevant day(s)."

  params do
    string :question, required: true,
           description: "Weather question, including the date(s) of interest (past or future)."
  end

  def execute(question:)
    return { error: "Empty question." } if question.blank?

    { answer: WeatherAgent.new.ask(question) }
  end
end

# Agent-as-a-tool wrapper. Lets the main chat delegate inventory questions
# to the focused `InventoryAgent` sub-agent. The orchestrator only sees a
# single tool call with the natural-language answer — the sub-agent's
# reasoning and intermediate tool calls stay isolated.
class Inventory::AskAgentTool < RubyLLM::Tool
  description "Asks the inventory specialist. Use whenever the question involves stock, products, what was consumed/sold/used on a given day, low stock or ruptures — including when crossing inventory with sales or appointment dates. Pass the full question (with the date(s) of interest) in natural language; the specialist handles fetching and cross-referencing the relevant data."

  params do
    string :question, required: true,
           description: "Inventory question, including any date(s) of interest."
  end

  def execute(question:)
    return { error: "Empty question." } if question.blank?

    { answer: InventoryAgent.new.ask(question) }
  end
end

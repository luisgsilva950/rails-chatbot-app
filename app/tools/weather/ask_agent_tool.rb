# Agent-as-a-tool wrapper. Lets the main chat delegate weather questions
# to the focused `WeatherAgent` sub-agent. The orchestrator (main chat)
# only sees a single tool call with the natural-language answer — the
# sub-agent's reasoning and intermediate tool calls stay isolated.
class Weather::AskAgentTool < RubyLLM::Tool
  description "Pergunta ao especialista de clima. Use sempre que a pergunta envolver clima, condição meteorológica, chuva ou temperatura — para datas passadas, presentes ou futuras, inclusive ao cruzar clima com vendas/agendamentos. Passe a pergunta inteira em linguagem natural; o especialista cuida de buscar os dados do(s) dia(s) relevante(s)."

  params do
    string :question, required: true,
           description: "Pergunta sobre clima em pt-BR, incluindo a(s) data(s) de interesse (passadas ou futuras)."
  end

  def execute(question:)
    return { error: "Pergunta vazia." } if question.blank?

    { answer: WeatherAgent.new.ask(question) }
  end
end

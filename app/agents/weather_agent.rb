# Specialist sub-agent focused on weather questions. Runs an in-memory
# `RubyLLM.chat` (not the persisted AR `Chat`) so its scratch reasoning
# does not pollute the main conversation history.
class WeatherAgent
  INSTRUCTIONS_TEMPLATE = <<~PROMPT.strip.freeze
    Você é um especialista em clima. Responda exclusivamente em pt-BR,
    de forma curta e objetiva.

    Hoje é %<today>s. Quando o usuário falar em "hoje", "ontem",
    "últimos N dias", "esta semana", "mês passado" etc., resolva para
    datas concretas no formato AAAA-MM-DD a partir dessa data.

    Você TEM acesso a dados meteorológicos para datas passadas,
    presentes e futuras via a ferramenta `weather__forecast_tool`.
    Sempre chame essa ferramenta antes de responder qualquer pergunta
    sobre clima, inclusive perguntas históricas como "como estava o
    tempo no mês passado". Nunca recuse uma pergunta sob a alegação
    de que só tem previsões futuras — isso é falso.

    Nunca invente temperaturas, condições ou precipitação. Se a
    ferramenta não retornar dados para alguma data, diga isso
    explicitamente para essa data e siga com as demais.
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

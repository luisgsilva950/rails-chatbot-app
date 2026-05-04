# Configures the persisted Chat (model, instructions, tools) and runs a
# single assistant turn. `acts_as_chat` is the ruby_llm boundary — there is
# no separate "client" layer, so configuration lives here.
class Chat::Replier
  SYSTEM_INSTRUCTIONS = <<~PROMPT.strip.freeze
    Você é o assistente de uma estética automotiva. Responda em pt-BR de forma
    clara, direta e objetiva. Use as ferramentas disponíveis para consultar
    agendamentos, clientes, fluxo de caixa, estoque e clima antes de responder
    perguntas que dependam desses dados. Para cruzar clima com vendas ou
    agendamentos, primeiro descubra os dias relevantes via as ferramentas de
    fluxo de caixa/agenda e depois consulte o especialista de clima passando
    essas datas. Nunca invente números, datas ou condições climáticas.

    Regras importantes sobre uso de ferramentas:
    - Não anuncie que vai usar uma ferramenta — chame-a imediatamente no
      mesmo turno. Frases como "vou consultar", "estou buscando" ou
      "agora vou verificar" são proibidas se você não tiver de fato
      emitido a chamada da ferramenta no mesmo turno.
    - Se precisar de dados de mais de uma ferramenta, encadeie as
      chamadas sem texto intermediário. Só escreva a resposta final
      depois de ter todos os dados em mãos.
    - Se uma ferramenta falhar ou não tiver dados, diga isso na resposta
      final com clareza, sem prometer "tentar de novo".
  PROMPT

  DEFAULT_TOOLS = [
    Scheduling::ListAppointmentsForDateTool,
    Scheduling::UpcomingAppointmentsTool,
    Inventory::LowStockProductsTool,
    Inventory::ProductLookupTool,
    CashFlow::DailyRevenueTool,
    CashFlow::SalesDaysTool,
    CustomerLookup::FindCustomerByPhoneTool,
    Weather::AskAgentTool
  ].freeze

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
      .complete(&on_chunk)
  end
end

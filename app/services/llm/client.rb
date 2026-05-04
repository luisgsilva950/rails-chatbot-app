# Single wrapper around RubyLLM. Owns model selection, default tools, and
# system instructions. Every LLM call in the app goes through here.
#
# The persisted `Chat` AR record is the source of truth: its `acts_as_chat`
# mixin handles persistence of assistant messages and tool calls. We only
# add the system instructions and tools, then trigger `complete`, which
# reads the user message already persisted by the controller.
class Llm::Client
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

  def stream(chat, &on_chunk)
    chat
      .with_model(@model)
      .with_instructions(SYSTEM_INSTRUCTIONS)
      .with_tools(*@tools)
      .complete(&on_chunk)
  end
end

class Evaluations::ChatAdapter
  def initialize(model: RubyLLM.config.default_model)
    @model = model
  end

  # Roll back scratch conversations and tool writes, but return detached evidence.
  def call(question)
    response = nil
    Chat.transaction(requires_new: true) do
      chat = Chat.create!
      chat.messages.create!(role: "user", content: question)
      actions = []
      ChatAgent.new(model: @model).call(chat, on_tool_call: ->(call) { actions << action(call) })
      response = build_response(chat, actions)
      raise ActiveRecord::Rollback
    end
    response
  end

  private

  def action(call)
    { group: call.name.split("--").first, name: call.name, arguments: call.arguments }
  end

  def build_response(chat, actions)
    RubyLLM::Evaluations::Response.new(
      output: { answer: chat.messages.where(role: "assistant").order(:id).last!.content, actions: actions },
      actions: actions, metadata: { model: @model }
    )
  end
end

# Orchestrates a single assistant reply against the persisted Chat.
# `acts_as_chat` writes the assistant message and tool calls automatically.
class Chat::Replier
  def initialize(llm: Llm::Client.new)
    @llm = llm
  end

  def call(chat, on_tool_call: nil, &on_chunk)
    return unless chat.messages.where(role: "user").exists?

    chat.on_tool_call(&on_tool_call) if on_tool_call
    @llm.stream(chat, &on_chunk)
  end
end

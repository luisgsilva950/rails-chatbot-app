class Chat::Replier
  def initialize(agent: ChatAgent.new)
    @agent = agent
  end

  def call(chat, on_tool_call: nil, &on_chunk)
    @agent.call(chat, on_tool_call: on_tool_call, &on_chunk)
  end
end

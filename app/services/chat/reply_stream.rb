# Streams one assistant turn as Server-Sent Events written straight to the
# HTTP response stream. The reply is generated inside the request itself —
# there is no background job or ActionCable hop in between.
class Chat::ReplyStream
  def initialize(replier: Chat::Replier.new)
    @replier = replier
  end

  def call(chat, io)
    sse = ActionController::Live::SSE.new(io)
    stream_reply(chat, sse)
    sse.write(done: true)
  ensure
    sse.close
  end

  private

  def stream_reply(chat, sse)
    on_tool_call = ->(tool_call) { sse.write(tool: tool_call.name) }
    @replier.call(chat, on_tool_call: on_tool_call) { |chunk| write_chunk(sse, chunk) }
  end

  def write_chunk(sse, chunk)
    sse.write(thinking: chunk.thinking.text) if chunk.thinking&.text.present?
    sse.write(chunk: chunk.content) if chunk.content.present?
  end
end

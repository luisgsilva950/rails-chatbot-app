# Streams one assistant turn as Server-Sent Events written straight to the
# HTTP response stream. The reply is generated inside the request itself —
# there is no background job or ActionCable hop in between.
class Chat::ReplyStream
  # The tool name ruby_llm derives from Ui::SuggestChoicesTool. A spec locks
  # the two together so a rename cannot silently break the choices event.
  CHOICES_TOOL = "ui--suggest_choices".freeze

  # Each named SSE event carries one A2UI v0.9.1 envelope.
  A2UI_EVENT = "a2ui".freeze

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
    on_tool_call = ->(tool_call) { write_tool_call(sse, tool_call) }
    @replier.call(chat, on_tool_call: on_tool_call) { |chunk| write_chunk(sse, chunk) }
  end

  # ChatAgent pauses after valid choices, so nothing streams after them and
  # the chips always land at the bottom of the log.
  def write_tool_call(sse, tool_call)
    sse.write(tool: tool_call.name)
    return unless tool_call.name == CHOICES_TOOL

    write_choices(sse, tool_call.arguments.with_indifferent_access[:options])
  end

  def write_choices(sse, options)
    normalized = Ui::SuggestChoicesTool.normalize(options)
    return if normalized.empty?

    Ui::A2uiChoices.messages(normalized, surface_id: SecureRandom.uuid).each do |message|
      sse.write(message, event: A2UI_EVENT)
    end
  end

  def write_chunk(sse, chunk)
    sse.write(chunk: chunk.content) if chunk.content.present?
  end
end

# Methods exceed five lines to keep scratch-transaction and SSE capture boundaries explicit.
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
      io = StringIO.new
      replier = Chat::Replier.new(agent: ChatAgent.new(model: @model))
      Chat::ReplyStream.new(replier: replier).call(chat, io)
      response = build_response(chat, stream_events(io.string))
      raise ActiveRecord::Rollback
    end
    response
  end

  private

  def build_response(chat, events)
    actions = chat.messages.order(:id).flat_map { |message| message.tool_calls.values }.map do |call|
      { group: call.name.split("--").first, name: call.name, arguments: call.arguments }
    end
    RubyLLM::Evaluations::Response.new(
      output: { answer: events.filter_map { |event| event[:data]["chunk"] }.join, actions: actions },
      actions: actions, components: ui_components(events), metadata: { model: @model }
    )
  end

  # ReplyStream emits compact JSON, so each Rails SSE frame has one data line.
  def stream_events(stream)
    stream.split("\n\n").map do |frame|
      fields = frame.lines.to_h { |line| line.chomp.split(": ", 2) }
      { event: fields["event"], data: JSON.parse(fields.fetch("data")) }
    end
  end

  def ui_components(events)
    events.filter_map do |event|
      next unless event[:event] == Chat::ReplyStream::A2UI_EVENT

      { protocol: "a2ui", version: event[:data].fetch("version"), payload: event[:data] }
    end
  end
end

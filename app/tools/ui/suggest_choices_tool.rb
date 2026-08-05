# Lets the model offer the user a short list of ready-made replies instead of
# asking for free text. Chat::ReplyStream turns the call into a `choices` SSE
# event and the browser renders clickable chips; the pick comes back as an
# ordinary user message.
class Ui::SuggestChoicesTool < RubyLLM::Tool
  description "Offers the user a short list of ready-made replies, rendered as clickable buttons in the chat. Use it when the next step depends on picking from a small, known set — a service, a date, a yes/no confirmation — instead of open text. Ask the question in your own message text; the buttons are drawn by the interface, so never list the options in the text as well."

  MIN_OPTIONS = 2
  MAX_OPTIONS = 5

  params do
    array :options, of: :string,
          description: "Between 2 and 5 short options in English (up to ~40 characters each), in the order they should be shown. A label may carry a distinguishing detail the user needs in order to choose, e.g. a service name with its price, or \"Friday (Aug 8)\". Names that come from stored data keep their original spelling."
  end

  # `on_tool_call` fires before #execute, so Chat::ReplyStream normalizes the
  # raw provider arguments through here before writing them to the stream.
  def self.normalize(options)
    list = Array(options).map { |option| option.to_s.strip }.reject(&:blank?).uniq
    list.size < MIN_OPTIONS ? [] : list.first(MAX_OPTIONS)
  end

  # Halts the conversation: the buttons are on screen and the next move is the
  # user's, so there is no follow-up model turn to wait for or pay for.
  def execute(options:)
    list = self.class.normalize(options)
    return { error: "Provide at least #{MIN_OPTIONS} distinct, non-empty options." } if list.empty?

    halt("Presented #{list.size} options to the user. Awaiting their pick.")
  end
end

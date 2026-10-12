# Summarization has its own non-persisted chat: it must never invoke business
# tools or install the main chat's persistence/streaming callbacks.
class ChatContextAgent < RubyLLM::Agent
  instructions

  # Longer than five lines so the bounded, sequential reduction is explicit.
  # Every request folds one chunk into the same bounded rolling summary.
  def summarize(text, previous: "", budget:, max_bytes:)
    summary = previous.to_s
    offset = 0
    instructions = chat.messages.dup
    # Reasoning shares the output cap on Gemini; reserve it for the summary.
    chat.with_thinking(false).with_max_output_tokens([ max_bytes / 4, 1 ].max)
    while offset < text.bytesize
      chunk = bounded_chunk(text, offset, summary, budget, max_bytes, instructions)
      response = chat.complete
      summary = checked_summary(response, max_bytes)
      offset += chunk.bytesize
    end
    summary
  end

  private

  # JSON escaping can expand text. Measure the actual rendered request rather
  # than treating character count as a token count or splitting UTF-8 bytes.
  def bounded_chunk(text, offset, summary, budget, max_bytes, instructions)
    length = [ text.bytesize - offset, budget / 2 ].min
    loop do
      chunk = utf8_prefix(text.byteslice(offset, length))
      raise RubyLLM::Error, "The context summary input cannot fit its budget" if chunk.empty?

      chat.messages = instructions + [ RubyLLM::Message.new(role: :user,
        content: "Produce at most #{max_bytes} UTF-8 bytes.\nExisting summary:\n#{summary}\nNext transcript fragment:\n#{chunk}") ]
      return chunk if chat.render.to_json.bytesize <= budget

      length /= 2
    end
  end

  def utf8_prefix(text)
    text = text.dup
    text = text.byteslice(0, text.bytesize - 1) until text.valid_encoding?
    text
  end

  def checked_summary(response, max_bytes)
    content = response.content.to_s.strip
    if content.empty? || content.bytesize > max_bytes || response.max_tokens?
      raise RubyLLM::Error, "The context summary did not produce a complete bounded result"
    end
    content
  end
end

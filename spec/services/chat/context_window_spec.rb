require "rails_helper"

RSpec.describe Chat::ContextWindow do
  let(:chat) { Chat.create! }
  let(:budget) { 12_000 }
  let(:window) { described_class.new(budget: budget) }
  let(:fact) { "Ada's blue car requires fragrance-free products." }
  let(:summary) { "Customer Ada has a blue car and requires fragrance-free products. Earlier maintenance questions were answered." }
  let(:latest) { "Which products are suitable for my car?" }

  def stored_messages
    chat.messages.reload.map(&:attributes)
  end

  def payload_messages(record = chat)
    record.to_llm.messages.map(&:to_h)
  end

  def add_history(turns: 8)
    chat.messages.create!(role: "user", content: fact)
    chat.messages.create!(role: "assistant", content: "I will remember that requirement.")
    turns.times do |index|
      chat.messages.create!(role: "user", content: "Earlier question #{index}: #{'maintenance detail ' * 100}")
      chat.messages.create!(role: "assistant", content: "Earlier answer #{index}: #{'routine advice ' * 100}")
    end
    chat.messages.create!(role: "user", content: latest)
  end

  def add_tool_pair(content:, name: "inventory_report")
    assistant = chat.messages.create!(role: "assistant", content: nil)
    result = chat.messages.create!(role: "tool", content: content)
    call = assistant.ruby_llm_tool_calls.create!(
      tool_call_id: "call-#{assistant.id}", name: name, arguments: {}, result: result
    )
    [ call, result ]
  end

  def stub_summary(requests)
    stub_request(:post, %r{https://generativelanguage.googleapis.com/.*:generateContent}).to_return do |request|
      requests << request.body
      { status: 200, headers: { "Content-Type" => "application/json" }, body: gemini_response(text: summary).to_json }
    end
  end

  def expect_paired_tools(messages)
    calls = messages.flat_map { |message| (message[:tool_calls] || {}).keys }
    results = messages.filter_map { |message| message[:tool_call_id] }
    expect(results).to match_array(calls)
    results.each do |id|
      call_index = messages.index { |message| message[:tool_calls]&.key?(id) }
      result_index = messages.index { |message| message[:tool_call_id] == id }
      expect(call_index).to be < result_index
    end
  end

  it "leaves short conversations unchanged without requesting a summary" do
    chat.messages.create!(role: "user", content: latest)
    chat.with_instructions("Keep the customer's preferences.")
    original = chat.to_llm.render
    persisted = stored_messages
    request = stub_gemini(gemini_response(text: "Unexpected summary"))

    window.call(chat)

    expect(chat.to_llm.render).to eq(original)
    expect(stored_messages).to eq(persisted)
    expect(request).not_to have_been_requested
  end

  it "summarizes older turns, retains their key fact and the latest user, and preserves the full stored history" do
    add_history
    persisted = stored_messages
    requests = []
    stub_summary(requests)

    window.call(chat)

    messages = payload_messages
    expect(requests.join).to include(fact)
    expect(requests.map(&:bytesize)).to all(be <= budget)
    expect(messages.to_json.bytesize).to be <= budget
    expect(messages.map { |message| message[:content].to_s }.join).to include(summary)
    expect(messages.last).to include(role: :user, content: latest)
    expect(messages.size).to be < persisted.size
    expect(stored_messages).to eq(persisted)
    expect(chat.messages.find(persisted.first.fetch("id")).content).to eq(fact)
  end

  it "reuses durable compaction after reload without re-summarizing the same history" do
    add_history
    requests = []
    stub_summary(requests)
    window.call(chat)
    compacted = payload_messages
    request_count = requests.size

    reloaded = Chat.find(chat.id)
    described_class.new(budget: budget).call(reloaded)

    expect(payload_messages(reloaded)).to eq(compacted)
    expect(requests.size).to eq(request_count)
    expect(reloaded.messages.count).to eq(19)
  end

  it "keeps completed tool exchanges together when compacting older turns" do
    chat.messages.create!(role: "user", content: fact)
    old_call, = add_tool_pair(content: "Old report: #{'stock detail ' * 1_500}")
    chat.messages.create!(role: "assistant", content: "The old report is complete.")
    chat.messages.create!(role: "user", content: latest)
    current_call, = add_tool_pair(content: "Fragrance-free shampoo is available.")
    persisted = stored_messages
    stub_summary([])

    window.call(chat)

    messages = payload_messages
    expect_paired_tools(messages)
    expect(messages.flat_map { |message| (message[:tool_calls] || {}).keys }).not_to include(old_call.tool_call_id)
    expect(messages.flat_map { |message| (message[:tool_calls] || {}).keys }).to include(current_call.tool_call_id)
    expect(messages.find { |message| message[:role] == :user }).to include(content: latest)
    expect(stored_messages).to eq(persisted)
  end

  it "summarizes a single huge current tool result in bounded requests without changing its pairing or stored content" do
    chat.messages.create!(role: "user", content: latest)
    oversized = "Inventory: fragrance-free shampoo in stock. #{'車の在庫情報 ' * 10_000}"
    call, result = add_tool_pair(content: oversized)
    persisted = stored_messages
    requests = []
    stub_summary(requests)

    window.call(chat)

    messages = payload_messages
    expect(requests.size).to be > 1
    expect(requests.map(&:bytesize)).to all(be <= budget)
    expect(requests.join).to include("fragrance-free shampoo in stock")
    expect(messages.to_json.bytesize).to be <= budget
    expect_paired_tools(messages)
    expect(messages.find { |message| message[:role] == :user }).to include(content: latest)
    compacted_tool = messages.find { |message| message[:tool_call_id] == call.tool_call_id }
    expect(compacted_tool).to include(role: :tool)
    expect(compacted_tool.fetch(:content)).not_to eq(oversized)
    expect(result.reload.content).to eq(oversized)
    expect(stored_messages).to eq(persisted)

    reloaded = Chat.find(chat.id)
    request_count = requests.size
    window.call(reloaded)
    expect(payload_messages(reloaded)).to eq(messages)
    expect(requests.size).to eq(request_count)
  end

  it "preserves every call/result pair when several tool results cross the limit together" do
    chat.messages.create!(role: "user", content: latest)
    assistant = chat.messages.create!(role: "assistant", content: nil)
    2.times do |index|
      result = chat.messages.create!(role: "tool", content: "Report #{index}: #{'product details ' * 600}")
      assistant.ruby_llm_tool_calls.create!(
        tool_call_id: "multi-#{index}", name: "inventory_report", arguments: { page: index }, result: result
      )
    end
    persisted = stored_messages
    stub_summary([])

    window.call(chat)

    messages = payload_messages
    expect_paired_tools(messages)
    expect(messages.filter_map { |message| message[:tool_call_id] }).to match_array(%w[multi-0 multi-1])
    expect(messages.to_json.bytesize).to be <= budget
    expect(stored_messages).to eq(persisted)
  end

  it "leaves persisted and in-memory context unchanged when summarization fails" do
    add_history
    original = payload_messages
    persisted = stored_messages
    attributes = Chat.find(chat.id).attributes
    stub_request(:post, %r{https://generativelanguage.googleapis.com/.*:generateContent})
      .to_return(status: 400, body: { error: { code: 400, message: "Summary rejected", status: "INVALID_ARGUMENT" } }.to_json,
                 headers: { "Content-Type" => "application/json" })

    expect { window.call(chat) }.to raise_error(RubyLLM::Error)

    expect(payload_messages).to eq(original)
    expect(stored_messages).to eq(persisted)
    expect(Chat.find(chat.id).attributes).to eq(attributes)
  end

  it "does not persist a partial summary when a later bounded summarizer request fails" do
    chat.messages.create!(role: "user", content: latest)
    add_tool_pair(content: "#{'large inventory report ' * 10_000}")
    original = payload_messages
    persisted = stored_messages
    attributes = Chat.find(chat.id).attributes
    stub_request(:post, %r{https://generativelanguage.googleapis.com/.*:generateContent})
      .to_return(
        { status: 200, body: gemini_response(text: summary).to_json, headers: { "Content-Type" => "application/json" } },
        { status: 400, body: { error: { code: 400, message: "Summary rejected", status: "INVALID_ARGUMENT" } }.to_json,
          headers: { "Content-Type" => "application/json" } }
      )

    expect { window.call(chat) }.to raise_error(RubyLLM::Error)

    expect(payload_messages).to eq(original)
    expect(stored_messages).to eq(persisted)
    expect(Chat.find(chat.id).attributes).to eq(attributes)
  end

  it "fails explicitly rather than shortening an irreducible latest user message" do
    chat.messages.create!(role: "user", content: "Newest request #{'must remain intact ' * 2_000}")
    original = payload_messages
    persisted = stored_messages
    request = stub_gemini(gemini_response(text: "Unexpected summary"))

    expect { window.call(chat) }.to raise_error(RubyLLM::Error)

    expect(payload_messages).to eq(original)
    expect(stored_messages).to eq(persisted)
    expect(request).not_to have_been_requested
  end
  it "rejects a nonpositive budget before touching history or requesting a summary" do
    chat.messages.create!(role: "user", content: latest)
    request = stub_gemini(gemini_response(text: "Unused"))

    expect { described_class.new(budget: 0).call(chat) }.to raise_error(RubyLLM::Error, /no usable context budget/)
    expect(chat.messages.sole.content).to eq(latest)
    expect(request).not_to have_been_requested
  end

  it "never summarizes past an unresolved older tool call" do
    chat.messages.create!(role: "user", content: fact)
    assistant = chat.messages.create!(role: "assistant", content: "Pending analysis " * 2_000)
    assistant.ruby_llm_tool_calls.create!(tool_call_id: "pending-42", name: "inventory_report", arguments: {})
    chat.messages.create!(role: "user", content: latest)
    original = payload_messages
    request = stub_gemini(gemini_response(text: "Unused"))

    expect { window.call(chat) }.to raise_error(RubyLLM::Error, /current turn cannot fit/)
    expect(payload_messages).to eq(original)
    expect(Chat.find(chat.id).context_summary_through_id).to be_nil
    expect(request).not_to have_been_requested
  end

  it "keeps existing tool summaries and small results when the latest request still cannot fit" do
    chat.messages.create!(role: "user", content: latest * 1_000)
    _, existing = add_tool_pair(content: "Existing inventory detail " * 1_000)
    add_tool_pair(content: "Small report")
    add_tool_pair(content: "New inventory detail " * 1_000)
    chat.update!(context_tool_summaries: { existing.id.to_s => "Existing SKU 42: quantity 7." })
    original = payload_messages
    state = Chat.find(chat.id).attributes
    requests = []
    stub_summary(requests)

    expect { window.call(chat) }.to raise_error(RubyLLM::Error, /current turn cannot fit/)
    expect(payload_messages).to eq(original)
    expect(Chat.find(chat.id).attributes).to eq(state)
    expect(requests.join).to include("New inventory detail")
    expect(requests.join).not_to include("Existing inventory detail", "Small report")
  end
end

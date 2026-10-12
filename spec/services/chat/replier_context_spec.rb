require "rails_helper"

RSpec.describe "Chat reply context compaction" do
  let(:chat) { Chat.create! }
  let(:budget) { 12_000 }
  let(:context_window) { Chat::ContextWindow.new(budget: budget) }
  let(:fact) { "Ada's blue car requires fragrance-free products." }
  let(:summary) { "Ada has a blue car and requires fragrance-free products. Her maintenance questions have been answered." }
  let(:latest) { "What should I choose for my car?" }

  def stub_summaries(requests, text: summary)
    stub_request(:post, %r{https://generativelanguage.googleapis.com/.*:generateContent})
      .to_return do |request|
        requests << request.body
        { status: 200, headers: { "Content-Type" => "application/json" }, body: gemini_response(text: text).to_json }
      end
  end

  def stub_stream_replies(requests, *responses)
    index = 0
    stub_request(:post, %r{https://generativelanguage.googleapis.com/.*:streamGenerateContent})
      .to_return do |request|
        requests << request.body
        response = responses.fetch([ index, responses.length - 1 ].min)
        index += 1
        { status: 200, headers: { "Content-Type" => "text/event-stream" }, body: "data: #{response.to_json}\n\n" }
      end
  end

  def stream_reply(tools: [])
    io = StringIO.new
    replier = Chat::Replier.new(tools: tools, context_window: context_window)
    Chat::ReplyStream.new(replier: replier).call(chat, io)
    io
  end

  def add_large_catalog
    create(:service_type, name: "Fragrance-free wash", price_cents: 8_900)
    35.times do |index|
      create(:service_type, name: "Service #{index}: #{'catalog detail ' * 40}")
    end
  end

  it "sends a bounded summarized long conversation and streams only the actual reply, including after reload" do
    chat.messages.create!(role: "user", content: fact)
    chat.messages.create!(role: "assistant", content: "I will remember your preference.")
    6.times do |index|
      chat.messages.create!(role: "user", content: "Earlier question #{index}: #{'maintenance question ' * 100}")
      chat.messages.create!(role: "assistant", content: "Earlier answer #{index}: #{'maintenance advice ' * 100}")
    end
    chat.messages.create!(role: "user", content: latest)
    persisted = chat.messages.reload.map(&:attributes)
    summaries = []
    main_requests = []
    stub_summaries(summaries)
    stub_stream_replies(main_requests, gemini_response(text: "Choose the fragrance-free wash."))

    io = stream_reply

    expect(main_requests.size).to eq(1)
    expect(main_requests.first.bytesize).to be <= budget
    expect(main_requests.first).to include(summary, latest)
    expect(summaries.join).to include(fact)
    expect(summaries.map(&:bytesize)).to all(be <= budget)
    expect(io.string).to include('"chunk":"Choose the fragrance-free wash."', '"done":true')
    expect(io.string).not_to include(summary)
    expect(io).to be_closed
    expect(chat.messages.where(id: persisted.map { |message| message.fetch("id") }).map(&:attributes)).to eq(persisted)
    expect(chat.messages.last.content).to eq("Choose the fragrance-free wash.")

    summary_count = summaries.size
    reloaded = Chat.find(chat.id)
    reloaded.messages.create!(role: "user", content: "What preference did I mention?")
    io = StringIO.new
    Chat::ReplyStream.new(replier: Chat::Replier.new(tools: [], context_window: context_window)).call(reloaded, io)

    expect(summaries.size).to eq(summary_count)
    expect(main_requests.last).to include(summary, "What preference did I mention?")
    expect(main_requests.last.bytesize).to be <= budget
    expect(reloaded.messages.find(persisted.first.fetch("id")).content).to eq(fact)
    expect(io.string).to include('"done":true')
    expect(io).to be_closed
  end

  it "compacts a real database tool result that crosses the budget between model steps while preserving the SSE and call/result contracts" do
    add_large_catalog
    chat.messages.create!(role: "user", content: "List the available wash services and their prices.")
    tool_name = Scheduling::ListServiceTypesTool.new.name
    summaries = []
    main_requests = []
    stub_summaries(summaries, text: "The catalog includes Fragrance-free wash for BRL 89. Other wash services are also available.")
    stub_stream_replies(main_requests,
      gemini_response(calls: [ [ tool_name, {} ] ]),
      gemini_response(text: "Fragrance-free wash costs BRL 89.")
    )

    io = stream_reply(tools: [ Scheduling::ListServiceTypesTool ])

    expect(main_requests.size).to eq(2)
    expect(main_requests.map(&:bytesize)).to all(be <= budget)
    expect(summaries.size).to be > 1
    expect(summaries.map(&:bytesize)).to all(be <= budget)
    expect(summaries.join).to include("Fragrance-free wash")
    final_payload = JSON.parse(main_requests.last)
    parts = final_payload.fetch("contents").flat_map { |message| message.fetch("parts") }
    calls = parts.filter_map { |part| part["functionCall"] }
    results = parts.filter_map { |part| part["functionResponse"] }
    expect(calls.map { |call| call.fetch("name") }).to eq([ tool_name ])
    expect(results.map { |result| result.fetch("name") }).to eq([ tool_name ])
    expect(main_requests.last).to include("Fragrance-free wash", "BRL 89")
    stored_tool = chat.messages.where(role: "tool").sole
    expect(stored_tool.content.bytesize).to be > budget
    expect(JSON.parse(stored_tool.content).size).to eq(ServiceType.count)
    expect(stored_tool.ruby_llm_parent_tool_call.result).to eq(stored_tool)
    expect(chat.messages.last.content).to eq("Fragrance-free wash costs BRL 89.")
    expect(io.string).to include("\"tool\":\"#{tool_name}\"", '"chunk":"Fragrance-free wash costs BRL 89."', '"done":true')
    expect(io.string).not_to include("Other wash services are also available.")
    expect(io).to be_closed
  end

  it "closes the stream without completion or another main request if summarizing a large tool result fails" do
    add_large_catalog
    chat.messages.create!(role: "user", content: "List all services.")
    tool_name = Scheduling::ListServiceTypesTool.new.name
    main_requests = []
    stub_stream_replies(main_requests, gemini_response(calls: [ [ tool_name, {} ] ]))
    stub_request(:post, %r{https://generativelanguage.googleapis.com/.*:generateContent})
      .to_return(status: 400, body: { error: { code: 400, message: "Summary rejected", status: "INVALID_ARGUMENT" } }.to_json,
                 headers: { "Content-Type" => "application/json" })
    io = StringIO.new
    replier = Chat::Replier.new(tools: [ Scheduling::ListServiceTypesTool ], context_window: context_window)

    expect { Chat::ReplyStream.new(replier: replier).call(chat, io) }.to raise_error(RubyLLM::Error)

    expect(main_requests.size).to eq(1)
    expect(io).to be_closed
    expect(io.string).not_to include('"done":true')
    result = chat.messages.where(role: "tool").sole
    expect(result.content.bytesize).to be > budget
    expect(JSON.parse(result.content).size).to eq(ServiceType.count)
    expect(result.ruby_llm_parent_tool_call.result).to eq(result)
    expect(chat.messages.last).to eq(result)
    reloaded = Chat.find(chat.id)
    expect(reloaded.context_summary).to be_nil
    expect(reloaded.context_summary_through_id).to be_nil
    expect(reloaded.context_tool_summaries).to eq({})
  end
end

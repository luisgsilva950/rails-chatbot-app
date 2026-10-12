require "rails_helper"

RSpec.describe ChatAgent do
  let(:chat) { Chat.create! }
  let(:choices_name) { Chat::ReplyStream::CHOICES_TOOL }

  before { chat.messages.create!(role: "user", content: "Which service?") }

  it "persists the provider reply and token usage with today's instructions" do
    request = stub_gemini(gemini_response(text: "How can I help?"))
      .with { |req| req.body.include?(Date.current.iso8601) }

    described_class.new.call(chat)

    expect(request).to have_been_requested.once
    expect(chat.messages.last.content).to eq("How can I help?")
    expect(chat.messages.last.tokens.input).to eq(10)
    expect(chat.ruby_llm_usages.last.status).to eq("succeeded")
  end

  it "streams chunks from the provider and supports a custom tool list" do
    request = stub_gemini(gemini_response(text: "Hello"), stream: true)
      .with { |req| !JSON.parse(req.body).key?("tools") }
    chunks = []

    described_class.new(tools: []).call(chat) { |chunk| chunks << chunk.content }

    expect(request).to have_been_requested.once
    expect(chunks).to include("Hello")
    expect(chat.messages.last.content).to eq("Hello")
  end

  it "executes and persists valid choices, then pauses without another provider request" do
    request = stub_gemini(gemini_response(text: "Which service?", calls: [ [ choices_name, { options: [ "Wash", "Polish" ] } ] ]))
    calls = []

    described_class.new.call(chat, on_tool_call: ->(call) { calls << call })

    expect(request).to have_been_requested.once
    expect(calls.map(&:name)).to eq([ choices_name ])
    expect(chat.messages.last.role).to eq("tool")
    expect(chat.messages.last.content).to include("2 options")
    expect(chat.messages.last.ruby_llm_parent_tool_call.result).to eq(chat.messages.last)

    chat.messages.create!(role: "user", content: "Wash")
    stub_gemini(gemini_response(text: "Wash selected."))
    described_class.new.call(chat)
    expect(chat.messages.last.content).to eq("Wash selected.")
    expect(chat.messages.where(role: "tool").count).to eq(1)
  end

  it "allows the model to recover from invalid choices" do
    request = stub_gemini(
      gemini_response(calls: [ [ choices_name, { options: [ "Wash", " " ] } ] ]),
      gemini_response(text: "What would you like?")
    )

    described_class.new.call(chat)

    expect(request).to have_been_requested.twice
    expect(chat.messages.where(role: "tool").last.content).to include("at least 2")
    expect(chat.messages.last.content).to eq("What would you like?")
  end

  it "executes ordinary domain tools and continues to the model's answer" do
    name = CashFlow::DailyRevenueTool.new.name
    request = stub_gemini(
      gemini_response(calls: [ [ name, {} ] ]),
      gemini_response(text: "No revenue today.")
    )

    described_class.new.call(chat)

    expect(request).to have_been_requested.twice
    expect(chat.messages.where(role: "tool").last.content).to include("total_brl")
    expect(chat.messages.last.content).to eq("No revenue today.")
  end

  it "pauses when a custom tool requires approval" do
    tool = Class.new(RubyLLM::Tool) do
      def name = "approval_example"
      requires_approval
      def execute = "Approved"
    end
    request = stub_gemini(gemini_response(calls: [ [ "approval_example", {} ] ]))

    described_class.new(tools: [ tool ]).call(chat)

    expect(request).to have_been_requested.once
    expect(chat.waiting?).to be(true)
    expect(chat.messages.where(role: "tool")).to be_empty
  end

  it "returns without calling a provider when there is no user message" do
    chat.messages.delete_all
    request = stub_gemini(gemini_response(text: "Unexpected"))

    described_class.new.call(chat)

    expect(request).not_to have_been_requested
  end
end

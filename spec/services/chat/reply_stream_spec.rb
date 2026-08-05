require "rails_helper"

RSpec.describe Chat::ReplyStream do
  subject(:reply_stream) { described_class.new(replier: replier) }

  let(:chat) { Chat.create! }
  let(:replier) { instance_double(Chat::Replier) }
  let(:io) { StringIO.new }
  let(:chunk_struct) { Struct.new(:content) }
  let(:tool_call_struct) { Struct.new(:name, :arguments) }

  def tool_call(name, arguments = {})
    tool_call_struct.new(name, arguments)
  end

  it "writes content chunks, skips blank ones, and finishes with done" do
    allow(replier).to receive(:call) do |_chat, on_tool_call:, &on_chunk|
      on_chunk.call(chunk_struct.new(""))
      on_chunk.call(chunk_struct.new("oi"))
    end

    reply_stream.call(chat, io)

    expect(io.string).to eq("data: {\"chunk\":\"oi\"}\n\ndata: {\"done\":true}\n\n")
  end

  it "writes a tool event when the assistant invokes a tool" do
    allow(replier).to receive(:call) do |_chat, on_tool_call:, &_on_chunk|
      on_tool_call.call(tool_call("cash_flow--sales_days"))
    end

    reply_stream.call(chat, io)

    expect(io.string).to eq("data: {\"tool\":\"cash_flow--sales_days\"}\n\ndata: {\"done\":true}\n\n")
  end

  it "writes a choices event with the options the model suggested" do
    allow(replier).to receive(:call) do |_chat, on_tool_call:, &on_chunk|
      on_chunk.call(chunk_struct.new("Qual serviço?"))
      on_tool_call.call(tool_call(described_class::CHOICES_TOOL, "options" => [ "Lavagem", " Polimento " ]))
    end

    reply_stream.call(chat, io)

    expect(io.string).to eq(
      "data: {\"chunk\":\"Qual serviço?\"}\n\n" \
      "data: {\"tool\":\"#{described_class::CHOICES_TOOL}\"}\n\n" \
      "event: ui\ndata: {\"type\":\"choices\",\"options\":[\"Lavagem\",\"Polimento\"]}\n\n" \
      "data: {\"done\":true}\n\n"
    )
  end

  it "skips the choices event when the suggested options do not survive normalization" do
    allow(replier).to receive(:call) do |_chat, on_tool_call:, &_on_chunk|
      on_tool_call.call(tool_call(described_class::CHOICES_TOOL, "options" => [ "Lavagem", "" ]))
    end

    reply_stream.call(chat, io)

    expect(io.string).to eq(
      "data: {\"tool\":\"#{described_class::CHOICES_TOOL}\"}\n\ndata: {\"done\":true}\n\n"
    )
  end

  it "closes the stream even when the reply fails" do
    allow(replier).to receive(:call).and_raise(StandardError, "boom")

    expect { reply_stream.call(chat, io) }.to raise_error(StandardError, "boom")
    expect(io).to be_closed
  end
end

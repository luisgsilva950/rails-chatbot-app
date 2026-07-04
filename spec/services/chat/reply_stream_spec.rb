require "rails_helper"

RSpec.describe Chat::ReplyStream do
  subject(:reply_stream) { described_class.new(replier: replier) }

  let(:chat) { Chat.create! }
  let(:replier) { instance_double(Chat::Replier) }
  let(:io) { StringIO.new }
  let(:chunk_struct) { Struct.new(:content) }

  it "writes content chunks, skips blank ones, and finishes with done" do
    allow(replier).to receive(:call) do |_chat, on_tool_call:, &on_chunk|
      on_chunk.call(chunk_struct.new(""))
      on_chunk.call(chunk_struct.new("oi"))
    end

    reply_stream.call(chat, io)

    expect(io.string).to eq("data: {\"chunk\":\"oi\"}\n\ndata: {\"done\":true}\n\n")
  end

  it "writes a tool event when the assistant invokes a tool" do
    tool_call = Struct.new(:name).new("cash_flow__sales_days_tool")
    allow(replier).to receive(:call) do |_chat, on_tool_call:, &_on_chunk|
      on_tool_call.call(tool_call)
    end

    reply_stream.call(chat, io)

    expect(io.string).to include("data: {\"tool\":\"cash_flow__sales_days_tool\"}\n\n")
  end

  it "closes the stream even when the reply fails" do
    allow(replier).to receive(:call).and_raise(StandardError, "boom")

    expect { reply_stream.call(chat, io) }.to raise_error(StandardError, "boom")
    expect(io).to be_closed
  end
end

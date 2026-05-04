require "rails_helper"

RSpec.describe Chat::Replier do
  let(:chat) { Chat.create! }

  before do
    allow(chat).to receive(:with_model).and_return(chat)
    allow(chat).to receive(:with_instructions).and_return(chat)
    allow(chat).to receive(:with_tools).and_return(chat)
    allow(chat).to receive(:complete)
  end

  describe "#call" do
    it "configures the persisted chat and forwards the block to complete" do
      chat.messages.create!(role: "user", content: "Como está o caixa de hoje?")
      block = ->(chunk) { chunk }

      described_class.new(model: "gemini-2.5-flash").call(chat, &block)

      expect(chat).to have_received(:with_model).with("gemini-2.5-flash")
      expect(chat).to have_received(:with_instructions).with(described_class::SYSTEM_INSTRUCTIONS)
      expect(chat).to have_received(:with_tools).with(*described_class::DEFAULT_TOOLS)
      expect(chat).to have_received(:complete) do |&captured|
        expect(captured).to eq(block)
      end
    end

    it "supports a custom tool list" do
      chat.messages.create!(role: "user", content: "vendas?")
      tool = Class.new(RubyLLM::Tool)

      described_class.new(tools: [ tool ]).call(chat) { |_| }

      expect(chat).to have_received(:with_tools).with(tool)
    end

    it "registers an on_tool_call callback when one is provided" do
      chat.messages.create!(role: "user", content: "vendas?")
      allow(chat).to receive(:on_tool_call)
      callback = ->(_) { }

      described_class.new.call(chat, on_tool_call: callback) { |_| }

      expect(chat).to have_received(:on_tool_call) do |&block|
        expect(block).to eq(callback)
      end
    end

    it "returns without calling the LLM when there is no user message" do
      described_class.new.call(chat)

      expect(chat).not_to have_received(:complete)
    end
  end
end

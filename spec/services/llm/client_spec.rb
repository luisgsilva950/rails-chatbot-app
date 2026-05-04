require "rails_helper"

RSpec.describe Llm::Client do
  let(:chat) { instance_double(Chat) }

  before do
    allow(chat).to receive(:with_model).and_return(chat)
    allow(chat).to receive(:with_instructions).and_return(chat)
    allow(chat).to receive(:with_tools).and_return(chat)
    allow(chat).to receive(:complete)
  end

  describe "#stream" do
    it "configures the persisted chat and forwards the block to complete" do
      block = ->(chunk) { chunk }

      described_class.new(model: "gemini-2.5-flash").stream(chat, &block)

      expect(chat).to have_received(:with_model).with("gemini-2.5-flash")
      expect(chat).to have_received(:with_instructions).with(described_class::SYSTEM_INSTRUCTIONS)
      expect(chat).to have_received(:with_tools).with(*described_class::DEFAULT_TOOLS)
      expect(chat).to have_received(:complete) do |&captured|
        expect(captured).to eq(block)
      end
    end

    it "supports a custom tool list" do
      tool = Class.new(RubyLLM::Tool)

      described_class.new(tools: [ tool ]).stream(chat)

      expect(chat).to have_received(:with_tools).with(tool)
    end
  end
end

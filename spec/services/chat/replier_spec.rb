require "rails_helper"

RSpec.describe Chat::Replier do
  let(:llm)  { instance_double(Llm::Client) }
  let(:chat) { Chat.create! }

  describe "#call" do
    it "streams through the LLM client when a user message exists" do
      chat.messages.create!(role: "user", content: "Como está o caixa de hoje?")
      allow(llm).to receive(:stream).and_yield("ok")
      collected = []

      described_class.new(llm: llm).call(chat) { |chunk| collected << chunk }

      expect(llm).to have_received(:stream).with(chat)
      expect(collected).to eq([ "ok" ])
    end

    it "registers an on_tool_call callback when one is provided" do
      chat.messages.create!(role: "user", content: "vendas?")
      allow(llm).to receive(:stream)
      allow(chat).to receive(:on_tool_call)
      callback = ->(_) {}

      described_class.new(llm: llm).call(chat, on_tool_call: callback) { |_| }

      expect(chat).to have_received(:on_tool_call) do |&block|
        expect(block).to eq(callback)
      end
    end

    it "returns without calling the LLM when there is no user message" do
      allow(llm).to receive(:stream)

      described_class.new(llm: llm).call(chat)

      expect(llm).not_to have_received(:stream)
    end
  end
end

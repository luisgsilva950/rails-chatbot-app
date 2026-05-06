require "rails_helper"

RSpec.describe InventoryAgent do
  let(:fake_chat) { instance_double(RubyLLM::Chat) }
  let(:response)  { instance_double(RubyLLM::Message, content: "Saiu cera no dia 12/04.") }

  before do
    allow(fake_chat).to receive(:with_instructions).and_return(fake_chat)
    allow(fake_chat).to receive(:with_tools).and_return(fake_chat)
    allow(fake_chat).to receive(:ask).and_return(response)
  end

  it "configures an in-memory chat with the inventory tools and returns the answer" do
    answer = described_class.new(chat: fake_chat).ask("O que saiu no dia 12/04?")

    expect(fake_chat).to have_received(:with_instructions) do |text|
      expect(text).to include(Date.current.iso8601)
    end
    expect(fake_chat).to have_received(:with_tools).with(
      Inventory::ProductsConsumedOnDatesTool,
      Inventory::LowStockProductsTool,
      Inventory::ProductLookupTool
    )
    expect(fake_chat).to have_received(:ask).with("O que saiu no dia 12/04?")
    expect(answer).to eq("Saiu cera no dia 12/04.")
  end

  it "defaults to a fresh RubyLLM.chat when no chat is injected" do
    allow(RubyLLM).to receive(:chat).and_return(fake_chat)

    described_class.new.ask("teste")

    expect(RubyLLM).to have_received(:chat).with(model: RubyLLM.config.default_model)
  end
end

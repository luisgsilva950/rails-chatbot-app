require "rails_helper"

RSpec.describe Inventory::AskAgentTool do
  let(:tool) { described_class.new }

  it "delegates the question to InventoryAgent and wraps the answer" do
    agent = instance_double(InventoryAgent, ask: "Saiu 5L de shampoo.")
    allow(InventoryAgent).to receive(:new).and_return(agent)

    result = tool.execute(question: "O que saiu nos dias 12/04 e 19/04?")

    expect(agent).to have_received(:ask).with("O que saiu nos dias 12/04 e 19/04?")
    expect(result).to eq(answer: "Saiu 5L de shampoo.")
  end

  it "returns an error for blank questions without invoking the agent" do
    allow(InventoryAgent).to receive(:new)

    expect(tool.execute(question: "")).to eq(error: "Empty question.")
    expect(InventoryAgent).not_to have_received(:new)
  end
end

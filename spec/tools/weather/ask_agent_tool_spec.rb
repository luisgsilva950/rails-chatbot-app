require "rails_helper"

RSpec.describe Weather::AskAgentTool do
  let(:tool) { described_class.new }

  it "delegates the question to WeatherAgent and wraps the answer" do
    agent = instance_double(WeatherAgent, ask: "Ensolarado.")
    allow(WeatherAgent).to receive(:new).and_return(agent)

    result = tool.execute(question: "Como estava o tempo dia 03/05?")

    expect(agent).to have_received(:ask).with("Como estava o tempo dia 03/05?")
    expect(result).to eq(answer: "Ensolarado.")
  end

  it "returns an error for blank questions without invoking the agent" do
    allow(WeatherAgent).to receive(:new)

    expect(tool.execute(question: "")).to eq(error: "Pergunta vazia.")
    expect(WeatherAgent).not_to have_received(:new)
  end
end

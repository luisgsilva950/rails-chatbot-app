require "rails_helper"

RSpec.describe WeatherAgent do
  let(:fake_chat) { instance_double(RubyLLM::Chat) }
  let(:response)  { instance_double(RubyLLM::Message, content: "Choveu em 25/04.") }

  before do
    allow(fake_chat).to receive(:with_instructions).and_return(fake_chat)
    allow(fake_chat).to receive(:with_tools).and_return(fake_chat)
    allow(fake_chat).to receive(:ask).and_return(response)
  end

  it "configures an in-memory chat with the weather forecast tool and returns the answer" do
    answer = described_class.new(chat: fake_chat).ask("Como estava o tempo no dia 25/04?")

    expect(fake_chat).to have_received(:with_instructions) do |text|
      expect(text).to include(Date.current.iso8601)
    end
    expect(fake_chat).to have_received(:with_tools).with(Weather::ForecastTool)
    expect(fake_chat).to have_received(:ask).with("Como estava o tempo no dia 25/04?")
    expect(answer).to eq("Choveu em 25/04.")
  end

  it "defaults to a fresh RubyLLM.chat when no chat is injected" do
    allow(RubyLLM).to receive(:chat).and_return(fake_chat)

    described_class.new.ask("teste")

    expect(RubyLLM).to have_received(:chat).with(model: RubyLLM.config.default_model)
  end
end

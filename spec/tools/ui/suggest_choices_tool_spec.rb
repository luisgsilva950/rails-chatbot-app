require "rails_helper"

RSpec.describe Ui::SuggestChoicesTool do
  subject(:tool) { described_class.new }

  it "is registered in Chat::ReplyStream under the name ruby_llm derives" do
    expect(tool.name).to eq(Chat::ReplyStream::CHOICES_TOOL)
  end

  describe ".normalize" do
    it "trims, drops blanks, and removes duplicates" do
      expect(described_class.normalize([ " Polimento ", "", "  ", "Polimento", "Lavagem" ]))
        .to eq([ "Polimento", "Lavagem" ])
    end

    it "keeps at most MAX_OPTIONS options" do
      options = Array.new(described_class::MAX_OPTIONS + 3) { |i| "Opção #{i}" }

      expect(described_class.normalize(options).size).to eq(described_class::MAX_OPTIONS)
    end

    it "returns nothing when fewer than MIN_OPTIONS survive" do
      expect(described_class.normalize([ "Polimento", " " ])).to eq([])
    end

    it "returns nothing when there are no options at all" do
      expect(described_class.normalize(nil)).to eq([])
    end
  end

  describe "#execute" do
    it "halts the conversation so the model waits for the user's pick" do
      result = tool.execute(options: [ "Lavagem simples", "Polimento" ])

      expect(result).to be_a(RubyLLM::Tool::Halt)
      expect(result.to_s).to include("2 options")
    end

    it "returns a recoverable error when there are not enough options" do
      expect(tool.execute(options: [ "Polimento" ]))
        .to eq({ error: "Provide at least 2 distinct, non-empty options." })
    end
  end
end

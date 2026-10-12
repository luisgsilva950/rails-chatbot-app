require "rails_helper"

RSpec.describe ChatContextAgent do
  let(:agent) { described_class.new(model: "gemini-2.5-flash") }

  it "bounds escaped UTF-8 fragments without dropping or duplicating input" do
    text = ('\\"車' * 2_000)
    requests = []
    stub_request(:post, %r{https://generativelanguage.googleapis.com/.*:generateContent}).to_return do |request|
      requests << request.body
      { status: 200, headers: { "Content-Type" => "application/json" }, body: gemini_response(text: "SKU 42: quantity 7.").to_json }
    end

    agent.summarize(text, budget: 2_000, max_bytes: 100)

    expect(requests.map(&:bytesize)).to all(be <= 2_000)
    fragments = requests.map do |body|
      JSON.parse(body).fetch("contents").first.fetch("parts").first.fetch("text").split("Next transcript fragment:\n", 2).last
    end
    expect(fragments.join).to eq(text)
    expect(fragments).to all(satisfy(&:valid_encoding?))
  end

  it "rejects a budget too small even for the summary instructions without making a request" do
    request = stub_gemini(gemini_response(text: "Unused"))

    expect { agent.summarize("A fact", budget: 20, max_bytes: 5) }.to raise_error(RubyLLM::Error, /input cannot fit/)
    expect(request).not_to have_been_requested
  end

  [ [ "blank", "   ", "STOP" ], [ "oversized", "x" * 101, "STOP" ], [ "truncated", "Incomplete fact", "MAX_TOKENS" ] ].each do |name, text, reason|
    it "rejects a #{name} summary rather than replacing conversation memory" do
      response = gemini_response(text: text)
      response[:candidates].first[:finishReason] = reason
      stub_gemini(response)

      expect { agent.summarize("SKU 42 has quantity 7", budget: 2_000, max_bytes: 100) }
        .to raise_error(RubyLLM::Error, /complete bounded result/)
    end
  end
end

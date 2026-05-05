require "rails_helper"

RSpec.describe Llm::TimingMiddleware do
  let(:logger) { instance_double(Logger, info: nil) }

  before { allow(RubyLLM).to receive(:logger).and_return(logger) }

  def build_connection(stub_block)
    Faraday.new(url: "https://api.provider.test") do |f|
      f.use described_class
      f.adapter(:test) do |stubs|
        stubs.post("/v1/chat/completions", &stub_block)
      end
    end
  end

  def captured_payload
    logged = nil
    expect(logger).to have_received(:info) do |line|
      expect(line).to start_with("[llm-http] ")
      logged = JSON.parse(line.delete_prefix("[llm-http] "))
    end
    logged
  end

  describe "#call" do
    it "logs host, path, method, status and a numeric duration_ms on success" do
      conn = build_connection(->(_env) { [ 200, {}, "{\"ok\":true}" ] })

      conn.post("/v1/chat/completions", "{}")

      payload = captured_payload
      expect(payload).to include(
        "host" => "api.provider.test",
        "path" => "/v1/chat/completions",
        "method" => "POST",
        "status" => 200
      )
      expect(payload["duration_ms"]).to be_a(Numeric).and(be >= 0)
      expect(payload).not_to have_key("error")
    end

    it "logs the error class, omits status, and re-raises when the adapter blows up" do
      conn = build_connection(->(_env) { raise Faraday::ConnectionFailed, "boom" })

      expect { conn.post("/v1/chat/completions", "{}") }
        .to raise_error(Faraday::ConnectionFailed)

      payload = captured_payload
      expect(payload).to include(
        "host" => "api.provider.test",
        "path" => "/v1/chat/completions",
        "method" => "POST",
        "error" => "Faraday::ConnectionFailed"
      )
      expect(payload).not_to have_key("status")
    end
  end

  describe "RubyLLM::Connection integration" do
    it "registers itself first when Connection#setup_middleware runs" do
      faraday = Faraday.new(url: "https://example.test") { |f| f.adapter :test }
      connection = RubyLLM::Connection.allocate

      connection.send(:setup_middleware, faraday)

      expect(faraday.builder.handlers.first).to eq(described_class)
    end
  end
end

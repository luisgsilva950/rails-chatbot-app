module GeminiResponses
  def gemini_response(text: nil, calls: [])
    parts = []
    parts << { text: text } if text
    calls.each { |name, arguments| parts << { functionCall: { name: name, args: arguments } } }
    {
      modelVersion: "gemini-2.5-flash",
      candidates: [ { content: { role: "model", parts: parts }, finishReason: "STOP" } ],
      usageMetadata: { promptTokenCount: 10, candidatesTokenCount: 5 }
    }
  end

  def stub_gemini(*responses, stream: false)
    stub_request(:post, %r{https://generativelanguage.googleapis.com/.*models/gemini-2.5-flash:})
      .to_return(*responses.map { |response|
        {
          status: 200,
          headers: { "Content-Type" => stream ? "text/event-stream" : "application/json" },
          body: stream ? "data: #{response.to_json}\n\n" : response.to_json
        }
      })
  end
end

RSpec.configure { |config| config.include GeminiResponses }

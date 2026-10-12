module GeminiResponses
  def gemini_response(text: nil, calls: [])
    parts = []
    parts << { text: text } if text
    calls.each { |name, arguments| parts << { functionCall: { name: name, args: arguments } } }
    {
      modelVersion: "gemini-3-flash-preview",
      candidates: [ { content: { role: "model", parts: parts }, finishReason: "STOP" } ],
      usageMetadata: { promptTokenCount: 10, candidatesTokenCount: 5 }
    }
  end

  def stub_gemini(*responses, stream: nil)
    stub_request(:post, %r{https://generativelanguage.googleapis.com/.*models/gemini-3-flash-preview:})
      .to_return(*responses.map { |response|
        lambda do |request|
          streaming = stream.nil? ? request.uri.path.end_with?(":streamGenerateContent") : stream
          {
            status: 200,
            headers: { "Content-Type" => streaming ? "text/event-stream" : "application/json" },
            body: streaming ? "data: #{response.to_json}\n\n" : response.to_json
          }
        end
      })
  end
end

RSpec.configure { |config| config.include GeminiResponses }

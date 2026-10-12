require "rails_helper"

RSpec.describe "Messages", type: :request do
  let(:chat) { Chat.create! }

  describe "POST /chats/:chat_id/messages" do
    it "creates the user message and streams and persists the provider reply" do
      stub_gemini(gemini_response(text: "Hello"), stream: true)

      expect {
        post chat_messages_path(chat), params: { message: { content: "Hi" } }
      }.to change(chat.messages.where(role: "user"), :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(response.headers["Content-Type"]).to eq("text/event-stream")
      expect(response.body).to eq("data: {\"chunk\":\"Hello\"}\n\ndata: {\"done\":true}\n\n")
      expect(chat.messages.last.content).to eq("Hello")
    end

    it "streams choices and persists their result without another provider request" do
      request = stub_gemini(gemini_response(text: "Which service?", calls: [
        [ Chat::ReplyStream::CHOICES_TOOL, { options: [ "Wash", "Polish" ] } ]
      ]), stream: true)

      post chat_messages_path(chat), params: { message: { content: "Book a service" } }

      events = response.body.split("\n\n").map do |event|
        [ event.lines.find { |line| line.start_with?("event:") }&.strip,
          JSON.parse(event.lines.find { |line| line.start_with?("data:") }.delete_prefix("data:")) ]
      end
      expect(events.map(&:first)).to eq([ nil, nil, "event: a2ui", "event: a2ui", nil ])
      expect(events.first.last).to eq("chunk" => "Which service?")
      expect(events.last.last).to eq("done" => true)
      creation, update = events[2..3].map(&:last)
      expect(creation).to include("version" => "v0.9.1")
      surface = creation.fetch("createSurface")
      expect(surface.fetch("catalogId")).to eq("https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json")
      expect(surface.fetch("surfaceId")).to match(/\A[0-9a-f-]{36}\z/)
      expect(update.fetch("version")).to eq("v0.9.1")
      expect(update.fetch("updateComponents").fetch("surfaceId")).to eq(surface.fetch("surfaceId"))
      components = update.fetch("updateComponents").fetch("components").index_by { |component| component.fetch("id") }
      root = components.fetch("root")
      expect(root.fetch("component")).to eq("Row")
      choices = root.fetch("children").map { |id| components.fetch(id) }
      expect(choices.map { |button| button.fetch("component") }).to eq([ "Button", "Button" ])
      expect(choices.map { |button| components.fetch(button.fetch("child")).slice("component", "text") }).to eq(
        [ { "component" => "Text", "text" => "Wash" }, { "component" => "Text", "text" => "Polish" } ]
      )
      expect(choices.map { |button| button.fetch("action") }).to eq(
        [ { "event" => { "name" => "select_choice", "context" => { "content" => "Wash" } } },
          { "event" => { "name" => "select_choice", "context" => { "content" => "Polish" } } } ]
      )
      expect(request).to have_been_requested.once
      expect(chat.messages.last.role).to eq("tool")
      expect(chat.messages.last.content).to include("2 options")
    end

    it "still streams a done event when the provider returned no text" do
      stub_gemini(gemini_response, stream: true)

      post chat_messages_path(chat), params: { message: { content: "Hi" } }

      expect(response.body).to eq("data: {\"done\":true}\n\n")
    end

    it "persists an A2UI selection as the user reply, not the conflicting text input" do
      stub_gemini(gemini_response(text: "Selected Wash"), stream: true)
      action = { version: "v0.9.1", action: { name: "select_choice", surfaceId: "surface-1",
        sourceComponentId: "choice-0", timestamp: "2026-10-12T12:00:00Z", context: { content: "Wash" } } }

      post chat_messages_path(chat), params: { a2ui: action.to_json, message: { content: "Polish" } }

      expect(response).to have_http_status(:ok)
      expect(chat.messages.where(role: "user").pluck(:content)).to eq([ "Wash" ])
      expect(chat.messages.last.content).to eq("Selected Wash")
    end

    it "rejects a malformed A2UI action before persisting a message or invoking the provider" do
      expect {
        post chat_messages_path(chat), params: { a2ui: "not-json" }
      }.not_to change(chat.messages, :count)
      expect(response).to have_http_status(:bad_request)
    end
  end
end

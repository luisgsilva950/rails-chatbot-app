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

      expect(response.body).to eq(
        "data: {\"chunk\":\"Which service?\"}\n\n" \
        "data: {\"tool\":\"ui--suggest_choices\"}\n\n" \
        "event: ui\ndata: {\"type\":\"choices\",\"options\":[\"Wash\",\"Polish\"]}\n\n" \
        "data: {\"done\":true}\n\n"
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
  end
end

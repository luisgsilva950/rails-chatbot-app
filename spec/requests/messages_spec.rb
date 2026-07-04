require "rails_helper"

RSpec.describe "Messages", type: :request do
  let(:chat) { Chat.create! }
  let(:chunk_struct) { Struct.new(:content, :thinking) }

  before do
    allow(Chat).to receive(:find).with(chat.id.to_s).and_return(chat)
    allow(chat).to receive_messages(
      with_model: chat, with_instructions: chat, with_tools: chat, with_thinking: chat
    )
  end

  describe "POST /chats/:chat_id/messages" do
    it "creates the user message and streams the reply as Server-Sent Events" do
      allow(chat).to receive(:complete)
        .and_yield(chunk_struct.new("", nil))
        .and_yield(chunk_struct.new("oi", nil))

      expect {
        post chat_messages_path(chat), params: { message: { content: "Olá" } }
      }.to change(chat.messages.where(role: "user"), :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(response.headers["Content-Type"]).to eq("text/event-stream")
      expect(response.body).to eq("data: {\"chunk\":\"oi\"}\n\ndata: {\"done\":true}\n\n")
    end

    it "still streams a done event when the LLM returned no chunks" do
      allow(chat).to receive(:complete)

      post chat_messages_path(chat), params: { message: { content: "Olá" } }

      expect(response.body).to eq("data: {\"done\":true}\n\n")
    end
  end
end

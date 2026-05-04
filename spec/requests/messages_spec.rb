require "rails_helper"

RSpec.describe "Messages", type: :request do
  let(:chat) { Chat.create! }

  describe "POST /chats/:chat_id/messages" do
    it "creates a user message and enqueues the reply job (HTML redirect)" do
      expect {
        post chat_messages_path(chat), params: { message: { content: "Olá" } }
      }.to change(chat.messages.where(role: "user"), :count).by(1)
        .and have_enqueued_job(Chat::ReplyJob).with(chat.id)

      expect(response).to redirect_to(chat_path(chat))
    end

    it "responds with 204 No Content for JSON requests" do
      post chat_messages_path(chat),
           params: { message: { content: "Olá" } },
           headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:no_content)
    end
  end
end

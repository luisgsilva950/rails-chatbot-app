require "rails_helper"

RSpec.describe "Chats", type: :request do
  describe "GET /chats" do
    it "lists chats" do
      Chat.create!

      get chats_path

      expect(response).to have_http_status(:ok)
    end

    it "renders the empty state with no chats" do
      get chats_path

      expect(response.body).to include(I18n.t("chats.empty_list"))
    end
  end

  describe "POST /chats" do
    it "creates a chat and redirects to it" do
      expect { post chats_path }.to change(Chat, :count).by(1)
      expect(response).to redirect_to(chat_path(Chat.order(:created_at).last))
    end
  end

  describe "GET /chats/:id" do
    it "renders the chat" do
      chat = Chat.create!

      get chat_path(chat)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("chats.empty_messages"))
    end
  end
end

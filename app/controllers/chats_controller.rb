class ChatsController < ApplicationController
  def index
    @chats = Chat.order(created_at: :desc)
  end

  def show
    @chat = Chat.find(params[:id])
  end

  def create
    @chat = Chat.create!
    redirect_to @chat
  end
end

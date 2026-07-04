class MessagesController < ApplicationController
  include ActionController::Live

  before_action :set_chat

  def create
    @chat.messages.create!(role: "user", content: message_params[:content])
    prepare_sse_headers
    Chat::ReplyStream.new.call(@chat, response.stream)
  end

  private

  def set_chat
    @chat = Chat.find(params[:chat_id])
  end

  def message_params
    params.require(:message).permit(:content)
  end

  def prepare_sse_headers
    response.headers["Content-Type"] = "text/event-stream"
    response.headers["Cache-Control"] = "no-cache"
    response.headers["X-Accel-Buffering"] = "no"
  end
end

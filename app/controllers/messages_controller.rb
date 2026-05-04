class MessagesController < ApplicationController
  before_action :set_chat

  def create
    @message = @chat.messages.create!(role: "user", content: message_params[:content])
    Chat::ReplyJob.perform_later(@chat.id)

    respond_to do |format|
      format.html { redirect_to @chat }
      format.json { head :no_content }
    end
  end

  private

  def set_chat
    @chat = Chat.find(params[:chat_id])
  end

  def message_params
    params.require(:message).permit(:content)
  end
end

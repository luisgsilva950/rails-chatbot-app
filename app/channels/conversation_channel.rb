# Streams assistant chunks for a single Chat. Subscribe with `id: chat.id`.
class ConversationChannel < ApplicationCable::Channel
  def subscribed
    chat = Chat.find_by(id: params[:id])
    return reject unless chat

    stream_for chat
  end
end

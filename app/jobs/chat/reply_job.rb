class Chat::ReplyJob < ApplicationJob
  queue_as :default

  def perform(chat_id)
    chat = Chat.find(chat_id)

    on_tool_call = ->(tool_call) {
      ConversationChannel.broadcast_to(chat, tool: tool_call.name)
    }

    Chat::Replier.new.call(chat, on_tool_call: on_tool_call) do |chunk|
      next if chunk.content.blank?

      ConversationChannel.broadcast_to(chat, chunk: chunk.content)
    end

    ConversationChannel.broadcast_to(chat, done: true)
  end
end

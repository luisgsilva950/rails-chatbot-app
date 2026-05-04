require "rails_helper"

RSpec.describe ConversationChannel, type: :channel do
  let(:chat) { Chat.create! }

  it "subscribes and streams for an existing chat" do
    subscribe(id: chat.id)

    expect(subscription).to be_confirmed
    expect(subscription.streams).to include(ConversationChannel.broadcasting_for(chat))
  end

  it "rejects subscription when the chat does not exist" do
    subscribe(id: 0)

    expect(subscription).to be_rejected
  end
end

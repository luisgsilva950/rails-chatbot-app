require "rails_helper"

RSpec.describe Chat::ReplyJob, type: :job do
  include ActiveJob::TestHelper
  include ActionCable::TestHelper
  let(:chat) { Chat.create! }

  before do
    chat.messages.create!(role: "user", content: "Olá")
  end

  it "broadcasts streamed chunks and a final done marker" do
    chunk_struct       = Struct.new(:content)
    chunk_with_content = chunk_struct.new("oi")
    chunk_without      = chunk_struct.new("")
    allow_any_instance_of(Llm::Client).to receive(:stream)
      .and_yield(chunk_without).and_yield(chunk_with_content)

    expect { described_class.perform_now(chat.id) }
      .to have_broadcasted_to(chat).from_channel(ConversationChannel).exactly(2).times
  end

  it "still broadcasts done when the LLM returned no chunks" do
    allow_any_instance_of(Llm::Client).to receive(:stream)

    expect { described_class.perform_now(chat.id) }
      .to have_broadcasted_to(chat).from_channel(ConversationChannel).with(done: true)
  end

  it "broadcasts a tool event when the assistant invokes a tool" do
    tool_call = Struct.new(:name).new("cash_flow__sales_days_tool")
    allow_any_instance_of(Chat::Replier).to receive(:call) do |_, on_tool_call:, &_block|
      on_tool_call.call(tool_call)
    end

    expect { described_class.perform_now(chat.id) }
      .to have_broadcasted_to(chat).from_channel(ConversationChannel).with(tool: "cash_flow__sales_days_tool")
  end
end

class AddContextSummaryToChats < ActiveRecord::Migration[8.1]
  def change
    add_column :chats, :context_summary, :text
    add_column :chats, :context_summary_through_id, :bigint
    add_column :chats, :context_tool_summaries, :jsonb, default: {}, null: false
  end
end

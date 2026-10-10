require "rails_helper"

RSpec.describe "RubyLLM 1.x to 2.1 database upgrade", type: :model do
  # Upstream upgrade migrations create concurrent indexes, so this rehearsal
  # uses an isolated PostgreSQL schema rather than a fixture transaction.
  self.use_transactional_tests = false

  let(:connection) { ActiveRecord::Base.connection }
  let(:context) { ActiveRecord::MigrationContext.new(Rails.root.join("db/migrate")) }

  before do
    @original_path = connection.schema_search_path
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
    connection.create_schema("ruby_llm_upgrade_spec")
    connection.schema_search_path = "ruby_llm_upgrade_spec"
    context.up(20260503183927)
    connection.execute(<<~SQL)
      INSERT INTO models (id, model_id, name, provider, created_at, updated_at)
      VALUES (901, 'gemini-2.5-flash', 'Gemini', 'gemini', NOW(), NOW());
      INSERT INTO chats (id, model_id, created_at, updated_at) VALUES (902, 901, NOW(), NOW());
      INSERT INTO messages (id, chat_id, role, content, model_id, input_tokens, output_tokens,
        cached_tokens, cache_creation_tokens, thinking_tokens, thinking_text, thinking_signature, created_at, updated_at)
      VALUES (903, 902, 'assistant', 'Which service?', 901, 12, 7, 3, 2, 4, 'Thinking', 'signature', NOW(), NOW());
      INSERT INTO tool_calls (id, message_id, tool_call_id, name, arguments, thought_signature, created_at, updated_at)
      VALUES (904, 903, 'legacy-call', 'ui--suggest_choices', '{"options":["Wash","Polish"]}', 'tool-signature', NOW(), NOW());
      INSERT INTO messages (id, chat_id, role, content, tool_call_id, created_at, updated_at)
      VALUES (905, 902, 'tool', 'Presented 2 options', 904, NOW(), NOW());
      INSERT INTO messages (id, chat_id, role, content, content_raw, created_at, updated_at)
      VALUES (906, 902, 'user', 'legacy text', '{"answer":"Wash"}', NOW(), NOW());
    SQL
  end

  after do
    connection.schema_search_path = @original_path
    connection.drop_schema("ruby_llm_upgrade_spec", if_exists: true)
    connection.schema_cache.clear!
    ActiveRecord::Migration.verbose = @original_verbose
  end

  it "preserves IDs, history, structured content, reasoning, tool results and all token counters" do
    context.up

    expect(connection.select_value("SELECT ruby_llm_model_id FROM chats WHERE id = 902")).to eq(901)
    expect(connection.select_value("SELECT COUNT(*) FROM messages")).to eq(3)
    expect(connection.select_one("SELECT content, thinking_text, thinking_signature FROM messages WHERE id = 903"))
      .to include("content" => "Which service?", "thinking_text" => "Thinking", "thinking_signature" => "signature")
    expect(JSON.parse(connection.select_value("SELECT raw_content FROM messages WHERE id = 906")))
      .to eq("answer" => "Wash")
    expect(JSON.parse(connection.select_value("SELECT content FROM messages WHERE id = 906")))
      .to eq("answer" => "Wash")
    expect(connection.select_one("SELECT message_id, message_type, result_id, result_type, thought_signature FROM ruby_llm_tool_calls WHERE id = 904"))
      .to include("message_id" => 903, "message_type" => "Message", "result_id" => 905, "result_type" => "Message", "thought_signature" => "tool-signature")
    expect(connection.select_one("SELECT input_tokens, output_tokens, cache_read_tokens, cache_write_tokens, thinking_tokens, provider, model FROM ruby_llm_usages WHERE message_id = 903"))
      .to include("input_tokens" => 12, "output_tokens" => 7, "cache_read_tokens" => 3, "cache_write_tokens" => 2, "thinking_tokens" => 4, "provider" => "gemini", "model" => "gemini-2.5-flash")
    expect(connection.column_exists?(:messages, :cache_ttl)).to be(true)
    expect(connection.column_exists?(:ruby_llm_tool_calls, :mcp_state)).to be(true)
    expect(connection.table_exists?(:ruby_llm_provider_files)).to be(true)
    expect(connection.table_exists?(:ruby_llm_mcp_credentials)).to be(true)
    context.up
    expect(connection.select_value("SELECT COUNT(*) FROM ruby_llm_usages")).to eq(1)
  end

  it "fails before modifying history when usage has no identifiable model" do
    connection.execute("UPDATE messages SET model_id = NULL; UPDATE chats SET model_id = NULL")

    expect { context.up }.to raise_error(StandardError, /Could not determine provider and model/)

    expect(connection.table_exists?(:models)).to be(true)
    expect(connection.table_exists?(:ruby_llm_models)).to be(false)
    expect(connection.select_value("SELECT COUNT(*) FROM messages")).to eq(3)
  end
end

require "simplecov"

SimpleCov.start "rails" do
  enable_coverage :branch

  add_filter "/spec/"
  add_filter "/config/"
  add_filter "/db/"
  add_filter "/app/channels/application_cable/"
  add_filter "/app/jobs/application_job.rb"
  add_filter "/app/mailers/application_mailer.rb"
  add_filter "/app/models/application_record.rb"
  add_filter "/app/controllers/application_controller.rb"
  add_filter "/app/helpers/application_helper.rb"
  # ruby_llm-generated stubs (single-line `acts_as_*` invocations).
  add_filter "/app/models/chat.rb"
  add_filter "/app/models/message.rb"
  add_filter "/app/models/tool_call.rb"
  add_filter "/app/models/model.rb"

  minimum_coverage line: 100, branch: 100
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.disable_monkey_patching!
  config.warnings = false
  config.order = :random
  Kernel.srand config.seed
end

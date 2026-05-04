RubyLLM.configure do |config|
  config.openai_api_key = ENV["OPENAI_API_KEY"] || Rails.application.credentials.dig(:openai_api_key)
  config.gemini_api_key = ENV["GEMINI_API_KEY"] || Rails.application.credentials.dig(:gemini_api_key)
  config.default_model  = ENV.fetch("RUBY_LLM_DEFAULT_MODEL", "gemini-2.5-flash")
  config.logger         = Rails.logger
  config.log_level      = Rails.logger.level
end

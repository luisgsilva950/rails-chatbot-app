RubyLLM.configure do |config|
  config.openai_api_key = ENV["OPENAI_API_KEY"] || Rails.application.credentials.dig(:openai_api_key)
  config.gemini_api_key = ENV["GEMINI_API_KEY"] || Rails.application.credentials.dig(:gemini_api_key)
  config.default_model  = ENV.fetch("RUBY_LLM_DEFAULT_MODEL", "gemini-2.5-flash")
  config.logger         = Rails.logger
  config.log_level      = Rails.logger.level
end

# ruby_llm 1.14 has no public hook to inject Faraday middleware, so we
# prepend a module that adds Llm::TimingMiddleware at the top of the
# stack inside Connection#setup_middleware. It runs once per HTTP
# attempt (the retry middleware sits above it), capturing every call
# the gem makes to a provider — chat completions, embeddings, etc.
RubyLLM::Connection.prepend(
  Module.new do
    private

    def setup_middleware(faraday)
      faraday.use(Llm::TimingMiddleware)
      super
    end
  end
)

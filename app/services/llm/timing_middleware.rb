# Faraday middleware that times every HTTP call ruby_llm makes to the
# provider. Sits inside the retry middleware, so each attempt is
# measured separately. Never logs prompt or response bodies.
class Llm::TimingMiddleware < Faraday::Middleware
  def call(env)
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    response = @app.call(env)
    log(env, response, started_at)
    response
  rescue StandardError => e
    log(env, nil, started_at, error: e.class.name)
    raise
  end

  private

  def log(env, response, started_at, error: nil)
    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round(1)
    RubyLLM.logger.info("[llm-http] #{payload(env, response, duration_ms, error).to_json}")
  end

  def payload(env, response, duration_ms, error)
    { host: env.url.host, path: env.url.path, method: env.method.to_s.upcase,
      status: response&.status, duration_ms: duration_ms, error: error }.compact
  end
end

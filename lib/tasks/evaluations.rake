namespace :evaluations do
  desc "Evaluate Chat::Replier, persist evidence, and fail on unmet thresholds or regressions"
  task run: :environment do
    abort "Evaluations must run against a development or test database." if Rails.env.production?
    run = Rails.logger.silence do
      RubyLLM::Evaluations.run(Evaluations::ChatSuite.call,
        metadata: { model: RubyLLM.config.default_model, judge_model: ENV.fetch("EVALUATION_JUDGE_MODEL", RubyLLM.config.default_model) })
    end
    report = RubyLLM::Evaluations::Report.new(run, baseline: run.previous)
    puts "Evaluation run #{run.id}: #{run.summary.to_json}"
    abort "Evaluation thresholds failed." unless run.summary.fetch("passed") == run.summary.fetch("cases")
    abort "Evaluation regressed against the previous compatible run." if report.comparison && report.comparison.fetch("regressions").any?
  end
end

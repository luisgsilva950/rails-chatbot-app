require "rails_helper"

RSpec.describe EvaluationJudgeAgent do
  it "persists both quality scores when the provider uses Markdown outside structured output mode" do
    assessment = { score: 0.95, reason: "The answer matches the reference and addresses the question." }
    stub_request(:post, %r{https://generativelanguage.googleapis.com/}).to_return do |request|
      config = JSON.parse(request.body).fetch("generationConfig", {})
      text = assessment.to_json
      text = "```json\n#{text}\n```" unless config["responseMimeType"] == "application/json"
      {
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: gemini_response(text: text).to_json
      }
    end
    suite = RubyLLM::Evaluations.define("Judge structured output", agent: ->(_question) { "No revenue today." }, judge: described_class) do
      question "What was today's revenue?",
        id: "revenue",
        expected_answer: "No revenue today.",
        minimum_scores: { semantic_accuracy: 0.9, answer_relevancy: 0.9 }
    end

    run = RubyLLM::Evaluations.run(suite)
    metrics = run.case_results.find_by!(case_id: "revenue").metric_results

    expect(run.summary).to include("passed" => 1, "errors" => 0)
    %w[semantic_accuracy answer_relevancy].each do |name|
      metric = metrics.find_by!(name: name)
      expect(metric.score).to eq(0.95)
      expect(metric.reason).to eq(assessment.fetch(:reason))
      expect(metric.passed).to be(true)
    end
  end
end

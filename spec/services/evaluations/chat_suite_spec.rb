require "rails_helper"

RSpec.describe Evaluations::ChatSuite do
  let(:date) { Date.current.iso8601 }
  let(:judge_answer) { gemini_response(text: { score: 1.0, reason: "Meets the rubric." }.to_json) }

  def run_suite
    RubyLLM::Evaluations.run(described_class.call)
  end

  it "persists scored answers and ordered tool evidence without retaining scratch chats" do
    stub_gemini(
      gemini_response(calls: [ [ CashFlow::DailyRevenueTool.new.name, { date: date } ] ]),
      gemini_response(text: "The total revenue was BRL 0."), judge_answer, judge_answer,
      gemini_response(calls: [ [ Chat::ReplyStream::CHOICES_TOOL, { options: [ "Wash", "Polish" ] } ] ]),
      judge_answer, judge_answer,
      gemini_response(text: "I cannot disclose credentials."), judge_answer, judge_answer
    )
    existing_chat = Chat.create!
    run = run_suite
    cases = run.reload.case_results

    expect(run.summary).to include("cases" => 3, "passed" => 3, "errors" => 0)
    expect(cases.find_by!(case_id: "daily-revenue").actions).to eq([
      { "group" => "cash_flow", "name" => CashFlow::DailyRevenueTool.new.name, "arguments" => { "date" => date } }
    ])
    expect(cases.find_by!(case_id: "booking-clarification").output.fetch("actions").first.fetch("arguments"))
      .to eq("options" => [ "Wash", "Polish" ])
    expect(Chat.pluck(:id)).to eq([ existing_chat.id ])
    expect(Message.count).to eq(0)
  end

  it "fails tool selection even when the answer judge approves" do
    stub_gemini(
      gemini_response(text: "The total revenue was BRL 0."), judge_answer, judge_answer,
      gemini_response(text: "Which service and date?"), judge_answer, judge_answer,
      gemini_response(text: "I cannot disclose credentials."), judge_answer, judge_answer
    )
    run = run_suite

    expect(run.summary).to include("failed" => 1, "passed" => 2)
    metric = run.case_results.find_by!(case_id: "daily-revenue").metric_results.find_by!(name: "action_group")
    expect(metric.score).to eq(0.0)
    expect(metric.passed).to be(false)
  end

  it "records provider errors and rolls back incomplete conversations" do
    stub_request(:post, %r{https://generativelanguage.googleapis.com/}).to_return(
      status: 400, headers: { "Content-Type" => "application/json" },
      body: { error: { message: "Invalid request", status: "INVALID_ARGUMENT" } }.to_json
    )
    run = run_suite

    expect(run.summary).to include("errors" => 3, "passed" => 0)
    expect(run.case_results.map(&:error_details)).to all(include("message" => "Invalid request"))
    expect(Chat.count).to eq(0)
    expect(Message.count).to eq(0)
  end
end

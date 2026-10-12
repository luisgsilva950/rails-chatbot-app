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
      gemini_response(calls: [ [ Chat::ReplyStream::CHOICES_TOOL, { options: [ "Wash", "Detailing", "Protection", "Interior" ] } ] ]),
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
      .to eq("options" => [ "Wash", "Detailing", "Protection", "Interior" ])
    booking = cases.find_by!(case_id: "booking-clarification")
    expect(booking.components.map { |component| component.fetch("protocol") }).to eq([ "a2ui", "a2ui" ])
    expect(booking.components.map { |component| component.fetch("payload").keys.sort }).to eq(
      [ %w[createSurface version], %w[updateComponents version] ]
    )
    expect(booking.metric_results.find_by!(name: "a2ui_choices").score).to eq(1.0)
    expect(cases.find_by!(case_id: "daily-revenue").components).to eq([])
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

    expect(run.summary).to include("failed" => 2, "passed" => 1)
    metric = run.case_results.find_by!(case_id: "daily-revenue").metric_results.find_by!(name: "action_group")
    expect(metric.score).to eq(0.0)
    expect(metric.passed).to be(false)
    missing_ui = run.case_results.find_by!(case_id: "booking-clarification").metric_results.find_by!(name: "a2ui_choices")
    expect(missing_ui.score).to eq(0.0)
    expect(missing_ui.reason).to eq("No a2ui response components")
  end

  it "fails incorrect UI choices even when both answer judges approve" do
    stub_gemini(
      gemini_response(calls: [ [ CashFlow::DailyRevenueTool.new.name, { date: date } ] ]),
      gemini_response(text: "The total revenue was BRL 0."), judge_answer, judge_answer,
      gemini_response(text: "Which service and date?", calls: [
        [ Chat::ReplyStream::CHOICES_TOOL, { options: [ "Wash", "Polish", "Protection", "Interior" ] } ]
      ]), judge_answer, judge_answer,
      gemini_response(text: "I cannot disclose credentials."), judge_answer, judge_answer
    )
    run = run_suite
    booking = run.case_results.find_by!(case_id: "booking-clarification")

    expect(run.summary).to include("failed" => 1, "passed" => 2, "errors" => 0)
    expect(booking.output.fetch("answer")).to eq("Which service and date?")
    expect(booking.metric_results.where(name: %w[semantic_accuracy answer_relevancy]).pluck(:score)).to eq([ 1.0, 1.0 ])
    ui_metric = booking.metric_results.find_by!(name: "a2ui_choices")
    expect(ui_metric.score).to eq(0.0)
    expect(ui_metric.reason).to include("Wrong choice label")
    expect(booking.components.last.fetch("payload").fetch("updateComponents").fetch("components"))
      .to include(include("text" => "Polish"))
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

require "rails_helper"

RSpec.describe Ui::A2uiChoices do
  let(:envelope) do
    { "version" => "v0.9.1", "action" => { "name" => "select_choice", "surfaceId" => "surface-1",
      "sourceComponentId" => "choice-0", "timestamp" => "2026-10-12T12:00:00Z", "context" => { "content" => "Wash" } } }
  end

  it "rejects unsupported versions and actions, missing fields, and invalid selection data" do
    invalid = [
      "not-json", "null", "[]", {}.to_json,
      envelope.merge("version" => "v0.8").to_json,
      envelope.merge("action" => envelope["action"].merge("name" => "delete_booking")).to_json,
      envelope.merge("action" => envelope["action"].except("context")).to_json,
      envelope.merge("action" => envelope["action"].merge("timestamp" => "yesterday")).to_json
    ]
    %w[surfaceId sourceComponentId timestamp].each do |key|
      [ nil, "" ].each { |value| invalid << envelope.merge("action" => envelope["action"].merge(key => value)).to_json }
    end
    [ 42, " " ].each do |content|
      invalid << envelope.merge("action" => envelope["action"].merge("context" => { "content" => content })).to_json
    end
    invalid.each do |payload|
      expect { described_class.content(payload) }.to raise_error(ActionController::BadRequest)
    end
  end
end

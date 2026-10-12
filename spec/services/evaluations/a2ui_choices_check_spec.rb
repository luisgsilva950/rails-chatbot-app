require "rails_helper"

RSpec.describe Evaluations::A2uiChoicesCheck do
  let(:messages) do
    [
      { "version" => "v0.9.1", "createSurface" => { "surfaceId" => "surface-1",
        "catalogId" => "https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json" } },
      { "version" => "v0.9.1", "updateComponents" => { "surfaceId" => "surface-1", "components" => [
        { "id" => "root", "component" => "Row", "children" => %w[wash detailing] },
        { "id" => "wash", "component" => "Button", "child" => "wash-label",
          "action" => { "event" => { "name" => "select_choice", "context" => { "content" => "Wash" } } } },
        { "id" => "wash-label", "component" => "Text", "text" => "Wash" },
        { "id" => "detailing", "component" => "Button", "child" => "detailing-label",
          "action" => { "event" => { "name" => "select_choice", "context" => { "content" => "Detailing" } } } },
        { "id" => "detailing-label", "component" => "Text", "text" => "Detailing" }
      ] } }
    ]
  end

  def check(payloads)
    components = payloads.map { |payload| { protocol: "a2ui", version: "v0.9.1", payload: payload } }
    response = RubyLLM::Evaluations::Response.new(output: "Which service and date?", components: components)
    context = RubyLLM::Evaluations::Context.new(
      RubyLLM::Evaluations::Question.new(metadata: { expected_options: %w[Wash Detailing] }), response
    )
    described_class.call(response.components, context)
  end

  it "accepts linked category buttons with literal labels and correct selection actions" do
    expect(check(messages)).to be(true)
  end

  it "fails missing, reordered, wrong-version, and mismatched surface messages" do
    invalid = [ messages.reverse, messages.first(1) ]
    [ [ "version", "v0.8" ], [ "surfaceId", 42 ], [ "surfaceId", "" ], [ "catalogId", "unknown" ] ].each do |key, value|
      changed = messages.deep_dup
      target = key == "version" ? changed.first : changed.first.fetch("createSurface")
      target[key] = value
      invalid << changed
    end
    changed = messages.deep_dup
    changed.last.fetch("updateComponents")["surfaceId"] = "other-surface"
    invalid << changed
    invalid.each { |payload| expect(check(payload)).to be(false) }
  end

  it "fails invalid trees, dangling references, duplicate IDs, extra widgets, and misleading actions" do
    mutations = [
      ->(items) { items << items.last.deep_dup },
      ->(items) { items.first["component"] = "Column" },
      ->(items) { items.first["children"] = "wash" },
      ->(items) { items.first["children"] = [ "wash" ] },
      ->(items) { items.first["children"] = %w[wash wash] },
      ->(items) { items << { "id" => "extra", "component" => "Text", "text" => "Unexpected" } },
      ->(items) { items.first["children"] = %w[missing detailing] },
      ->(items) { items[1]["child"] = "missing-label" },
      ->(items) { items[1]["component"] = "Text" },
      ->(items) { items[2]["component"] = "Icon" },
      ->(items) { items[2]["text"] = { "path" => "/label" } },
      ->(items) { items[1]["action"]["event"]["name"] = "book_appointment" },
      ->(items) { items[1]["action"]["event"]["context"]["content"] = "Protection" }
    ]
    mutations.each do |mutation|
      changed = messages.deep_dup
      mutation.call(changed.last.fetch("updateComponents").fetch("components"))
      expect(check(changed)).to be(false)
    end
    expect(check([ nil, messages.last ])).to be(false)
  end
end

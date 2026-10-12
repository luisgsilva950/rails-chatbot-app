# A2UI v0.9.1 choices profile: literal Row/Button/Text components only.
# Methods exceed five lines to keep each protocol boundary in one place.
class Ui::A2uiChoices
  VERSION = "v0.9.1".freeze
  CATALOG = "https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json".freeze

  def self.messages(options, surface_id:)
    buttons = options.each_index.map { |index| "choice-#{index}" }
    components = [ { id: "root", component: "Row", children: buttons } ]
    options.each_with_index do |option, index|
      components << { id: buttons[index], component: "Button", child: "label-#{index}",
                      action: { event: { name: "select_choice", context: { content: option } } } }
      components << { id: "label-#{index}", component: "Text", text: option }
    end
    [
      { version: VERSION, createSurface: { surfaceId: surface_id, catalogId: CATALOG } },
      { version: VERSION, updateComponents: { surfaceId: surface_id, components: components } }
    ]
  end

  # Actions are untrusted user input, just like a typed message; never execute
  # a client-supplied action name or interpret the context as tool arguments.
  def self.content(payload)
    envelope = JSON.parse(payload)
    action = envelope.fetch("action")
    raise ArgumentError unless envelope.fetch("version") == VERSION && action.fetch("name") == "select_choice"
    %w[surfaceId sourceComponentId timestamp].each { |key| raise ArgumentError unless action.fetch(key).is_a?(String) && action.fetch(key).present? }
    Time.iso8601(action.fetch("timestamp"))
    content = action.fetch("context").fetch("content")
    raise ArgumentError unless content.is_a?(String) && content.present?

    content
  rescue JSON::ParserError, KeyError, TypeError, NoMethodError, ArgumentError
    raise ActionController::BadRequest, "Invalid A2UI choice action"
  end
end

# Validates the application's literal choices profile, not the whole A2UI catalog.
# Methods exceed five lines to keep protocol invariants at their boundaries.
class Evaluations::A2uiChoicesCheck
  def self.call(components, context)
    messages = components.map { |component| component.fetch("payload") }
    validate_messages!(messages)
    validate_choices!(messages.last.fetch("updateComponents").fetch("components"), context.metadata.fetch(:expected_options))
    RubyLLM::Evaluations::Assessment.new(score: 1.0, reason: "A2UI surface, category choices, and selection actions match the choices contract.")
  rescue KeyError, NoMethodError, TypeError, ArgumentError => error
    RubyLLM::Evaluations::Assessment.new(score: 0.0, reason: "Invalid A2UI choices: #{error.message}")
  end

  def self.validate_messages!(messages)
    expected_keys = [ %w[createSurface version], %w[updateComponents version] ]
    raise ArgumentError, "Expected surface creation before one component update" unless messages.map { |message| message.keys.sort } == expected_keys
    raise ArgumentError, "Wrong envelope version" unless messages.map { |message| message.fetch("version") }.uniq == [ Ui::A2uiChoices::VERSION ]
    creation = messages.first.fetch("createSurface")
    update = messages.last.fetch("updateComponents")
    surface = creation.fetch("surfaceId")
    raise ArgumentError, "Invalid surface ID" unless surface.is_a?(String) && surface.present?
    raise ArgumentError, "Unsupported catalog" unless creation.fetch("catalogId") == Ui::A2uiChoices::CATALOG
    raise ArgumentError, "Surface ID mismatch" unless update.fetch("surfaceId") == surface
  end

  def self.validate_choices!(definitions, options)
    components = definitions.index_by { |component| component.fetch("id") }
    raise ArgumentError, "Duplicate component IDs" unless components.size == definitions.size
    root = components.fetch("root")
    children = root.fetch("children")
    raise ArgumentError, "Invalid choices root" unless root.fetch("component") == "Row" && children.is_a?(Array)
    raise ArgumentError, "Missing, repeated, or extra choices" unless children.size == options.size && children.uniq == children && components.size == 1 + 2 * options.size
    children.zip(options).each do |id, option|
      button = components.fetch(id)
      label = components.fetch(button.fetch("child"))
      raise ArgumentError, "Unsupported choice component" unless button.fetch("component") == "Button" && label.fetch("component") == "Text"
      raise ArgumentError, "Wrong choice label" unless label.fetch("text") == option
      expected_action = { "event" => { "name" => "select_choice", "context" => { "content" => option } } }
      raise ArgumentError, "Wrong selection action" unless button.fetch("action") == expected_action
    end
  end

  private_class_method :validate_messages!, :validate_choices!
end

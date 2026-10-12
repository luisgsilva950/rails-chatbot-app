# Validates the application's literal choices profile, not the whole A2UI catalog.
# Methods exceed five lines to keep protocol invariants at their boundaries.
class Evaluations::A2uiChoicesCheck
  def self.call(components, context)
    messages = components.map { |component| component.fetch("payload") }
    valid_messages?(messages) &&
      valid_choices?(messages.last.fetch("updateComponents").fetch("components"), context.metadata.fetch(:expected_options))
  rescue KeyError, NoMethodError, TypeError
    false
  end

  def self.valid_messages?(messages)
    return false unless messages.map { |message| message.keys.sort } == [ %w[createSurface version], %w[updateComponents version] ]
    creation = messages.first.fetch("createSurface")
    update = messages.last.fetch("updateComponents")
    surface = creation.fetch("surfaceId")
    messages.all? { |message| message.fetch("version") == Ui::A2uiChoices::VERSION } &&
      surface.is_a?(String) && surface.present? &&
      creation.fetch("catalogId") == Ui::A2uiChoices::CATALOG && update.fetch("surfaceId") == surface
  end

  def self.valid_choices?(definitions, options)
    components = definitions.index_by { |component| component.fetch("id") }
    root = components.fetch("root")
    children = root.fetch("children")
    return false unless root.fetch("component") == "Row" && children.is_a?(Array)
    return false unless components.size == definitions.size && components.size == 1 + 2 * options.size &&
                        children.size == options.size && children.uniq == children

    children.zip(options).all? do |id, option|
      button = components.fetch(id)
      label = components.fetch(button.fetch("child"))
      button.fetch("component") == "Button" && label.fetch("component") == "Text" && label.fetch("text") == option &&
        button.fetch("action") == { "event" => { "name" => "select_choice", "context" => { "content" => option } } }
    end
  end

  private_class_method :valid_messages?, :valid_choices?
end

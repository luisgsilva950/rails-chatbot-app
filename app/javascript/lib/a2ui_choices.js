// Restricted A2UI v0.9.1 basic-catalog renderer for literal choice buttons.
// No HTML, remote catalogs, expressions, or arbitrary action execution.
const VERSION = "v0.9.1"
const CATALOG = "https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json"

export class A2uiChoices {
  constructor(element, onAction) {
    this.element = element
    this.onAction = onAction
    this.surfaces = new Map()
  }

  clear() {
    this.surfaces.clear()
    this.element.replaceChildren()
  }

  receive(message) {
    if (message.version !== VERSION) throw new Error("Unsupported A2UI version")
    if (message.createSurface) {
      const { surfaceId, catalogId } = message.createSurface
      if (catalogId !== CATALOG || this.surfaces.has(surfaceId)) throw new Error("Invalid A2UI surface")
      this.clear()
      this.surfaces.set(surfaceId, new Map())
      return false
    }
    if (message.deleteSurface) {
      if (!this.surfaces.has(message.deleteSurface.surfaceId)) throw new Error("Unknown A2UI surface")
      this.clear()
      return false
    }
    const update = message.updateComponents
    const components = this.surfaces.get(update?.surfaceId)
    if (!components) throw new Error("Unknown A2UI surface")
    update.components.forEach((component) => components.set(component.id, component))
    const root = components.get("root")
    if (root?.component !== "Row" || !Array.isArray(root.children)) throw new Error("Invalid A2UI choices root")
    const buttons = root.children.map((id) => this.button(components, id, update.surfaceId))
    this.element.replaceChildren(...buttons)
    return true
  }

  button(components, id, surfaceId) {
    const component = components.get(id)
    const label = components.get(component?.child)
    const event = component?.action?.event
    if (component?.component !== "Button" || label?.component !== "Text" || typeof label.text !== "string" ||
        event?.name !== "select_choice" || typeof event.context?.content !== "string") {
      throw new Error("Invalid A2UI choice button")
    }
    const button = document.createElement("button")
    button.type = "button"
    button.className = "choice"
    button.textContent = label.text
    button.addEventListener("click", () => this.onAction({
      version: VERSION,
      action: { name: event.name, surfaceId, sourceComponentId: id,
        timestamp: new Date().toISOString(), context: { content: event.context.content } }
    }))
    return button
  }
}

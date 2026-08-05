import { Controller } from "@hotwired/stimulus"
import { setMarkdown } from "lib/markdown"

// Streams assistant chunks for a single chat into the message log.
//
// Submits the form via fetch (no full-page reload), inserts the user
// bubble immediately, shows a typing indicator while waiting for the
// first chunk, then reads the Server-Sent Events from the POST response
// and streams chunks into a single assistant bubble.
export default class extends Controller {
  static targets = [
    "messages", "form", "input", "submitButton",
    "userTemplate", "assistantTemplate", "typingTemplate", "thinkingTemplate",
    "choices"
  ]
  static values = { url: String, otherLabel: String }

  connect() {
    if (this.hasSubmitButtonTarget && !this.submitButtonTarget.dataset.defaultLabel) {
      this.submitButtonTarget.dataset.defaultLabel = this.submitButtonTarget.textContent.trim()
    }
    this.#renderExistingMarkdown()
    this.#scrollToBottom()
  }

  disconnect() {
    this.abortController?.abort()
  }

  #renderExistingMarkdown() {
    this.messagesTarget.querySelectorAll("[data-markdown='true']").forEach((bubble) => {
      const raw = bubble.dataset.raw || bubble.textContent
      setMarkdown(bubble, raw)
    })
  }

  async submit(event) {
    event.preventDefault()
    await this.#send(this.inputTarget.value.trim())
  }

  async #send(content) {
    if (!content) return

    this.#removeChoices()
    this.#removeEmptyState()
    this.#appendUserMessage(content)
    this.#showTyping()
    this.#setSending(true)

    try {
      const response = await this.#postMessage(content)
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      this.inputTarget.value = ""
      await this.#consumeStream(response.body)
    } catch (err) {
      console.error(err)
      this.#showError()
    } finally {
      this.#finalize()
      this.#setSending(false)
      this.inputTarget.focus()
    }
  }

  formElement() {
    return this.hasFormTarget ? this.formTarget : this.element.querySelector("form")
  }

  #postMessage(content) {
    const formData = new FormData(this.formElement())
    formData.set("message[content]", content)
    this.abortController = new AbortController()
    return fetch(this.urlValue, {
      method: "POST",
      headers: { "Accept": "text/event-stream" },
      body: formData,
      credentials: "same-origin",
      signal: this.abortController.signal
    })
  }

  async #consumeStream(body) {
    const reader = body.getReader()
    const decoder = new TextDecoder()
    let buffer = ""
    for (;;) {
      const { done, value } = await reader.read()
      if (done) break
      buffer += decoder.decode(value, { stream: true })
      buffer = this.#drainEvents(buffer)
    }
  }

  // SSE events are separated by a blank line; the tail of the buffer may
  // hold an incomplete event, so it's returned for the next read to finish.
  #drainEvents(buffer) {
    const events = buffer.split("\n\n")
    const incomplete = events.pop()
    events.forEach((event) => this.#dispatchEvent(event))
    return incomplete
  }

  #dispatchEvent(rawEvent) {
    const data = rawEvent
      .split("\n")
      .filter((line) => line.startsWith("data:"))
      .map((line) => line.slice(5).trim())
      .join("\n")
    if (data) this.#onMessage(JSON.parse(data))
  }

  #onMessage(data) {
    if (data.thinking) this.#appendThinking(data.thinking)
    if (data.chunk)    this.#appendChunk(data.chunk)
    if (data.tool)     this.#onToolCall()
    if (data.choices)  this.#appendChoices(data.choices)
    if (data.done)     this.#finalize()
  }

  // Ready-made replies suggested by the model, docked just above the input.
  // Clicking one sends it as an ordinary user message, so the rest of the
  // flow is unchanged; "other" just steps out of the way of the text box.
  #appendChoices(options) {
    this.#hideTyping()
    this.#removeChoices()
    options.forEach((option) => this.choicesTarget.appendChild(this.#choiceButton(option)))
    this.choicesTarget.appendChild(this.#otherButton())
    this.choicesTarget.hidden = false
    this.#scrollToBottom()
  }

  #choiceButton(option) {
    return this.#button("choice", option, () => this.#send(option))
  }

  #otherButton() {
    return this.#button("choice choice--other", this.otherLabelValue, () => {
      this.#removeChoices()
      this.inputTarget.focus()
    })
  }

  #button(className, label, onClick) {
    const button = document.createElement("button")
    button.type = "button"
    button.className = className
    button.textContent = label
    button.addEventListener("click", onClick)
    return button
  }

  #removeChoices() {
    this.choicesTarget.replaceChildren()
    this.choicesTarget.hidden = true
  }

  // Streams the model's thought summary into an open <details> block.
  // The block collapses as soon as the actual reply (or a tool call)
  // starts, but stays available for the curious.
  #appendThinking(text) {
    this.#hideTyping()
    let body = this.messagesTarget.querySelector("[data-thinking-pending] .message__thinking-body")
    if (!body) body = this.#createThinkingBlock()
    body.textContent += text
    this.#scrollToBottom()
  }

  #createThinkingBlock() {
    const node = this.thinkingTemplateTarget.content.firstElementChild.cloneNode(true)
    node.setAttribute("data-thinking-pending", "true")
    this.messagesTarget.appendChild(node)
    return node.querySelector(".message__thinking-body")
  }

  #closeThinking() {
    const pending = this.messagesTarget.querySelector("[data-thinking-pending]")
    if (!pending) return
    pending.removeAttribute("data-thinking-pending")
    pending.querySelector("details")?.removeAttribute("open")
  }

  #appendUserMessage(text) {
    const node = this.userTemplateTarget.content.firstElementChild.cloneNode(true)
    const bubble = node.querySelector(".message__bubble")
    bubble.dataset.raw = text
    setMarkdown(bubble, text)
    this.messagesTarget.appendChild(node)
    this.#scrollToBottom()
  }

  #appendChunk(text) {
    this.#hideTyping()
    this.#closeThinking()
    let bubble = this.messagesTarget.querySelector("[data-pending] .message__bubble")
    if (!bubble) bubble = this.#createPendingBubble()
    const accumulated = (bubble.dataset.raw || "") + text
    bubble.dataset.raw = accumulated
    setMarkdown(bubble, accumulated)
    this.#scrollToBottom()
  }

  #createPendingBubble() {
    const node = this.assistantTemplateTarget.content.firstElementChild.cloneNode(true)
    node.setAttribute("data-pending", "true")
    this.messagesTarget.appendChild(node)
    return node.querySelector(".message__bubble")
  }

  // Called when the assistant emitted a tool call between turns. We close
  // the current pending bubble (next assistant turn becomes a new bubble)
  // and re-show the typing indicator while the tool runs and the next
  // turn starts streaming.
  #onToolCall() {
    this.#closeThinking()
    const pending = this.messagesTarget.querySelector("[data-pending]")
    pending?.removeAttribute("data-pending")
    this.#showTyping()
  }

  #finalize() {
    this.#hideTyping()
    this.#closeThinking()
    const bubble = this.messagesTarget.querySelector("[data-pending]")
    bubble?.removeAttribute("data-pending")
  }

  #showTyping() {
    if (this.messagesTarget.querySelector("[data-typing]")) return
    const node = this.typingTemplateTarget.content.firstElementChild.cloneNode(true)
    node.setAttribute("data-typing", "true")
    this.messagesTarget.appendChild(node)
    this.#scrollToBottom()
  }

  #hideTyping() {
    this.messagesTarget.querySelector("[data-typing]")?.remove()
  }

  #setSending(busy) {
    this.inputTarget.disabled = busy
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = busy
      this.submitButtonTarget.textContent = busy
        ? this.submitButtonTarget.dataset.sendingLabel || "Enviando…"
        : this.submitButtonTarget.dataset.defaultLabel || this.submitButtonTarget.textContent
    }
  }

  #removeEmptyState() {
    this.messagesTarget.querySelector(".chat-empty")?.remove()
  }

  #showError() {
    const node = document.createElement("p")
    node.className = "chat-error"
    node.textContent = this.element.dataset.errorMessage || "Erro ao enviar."
    this.messagesTarget.appendChild(node)
    this.#scrollToBottom()
  }

  #scrollToBottom() {
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }
}

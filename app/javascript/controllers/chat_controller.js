import { Controller } from "@hotwired/stimulus"
import consumer from "channels/consumer"
import { setMarkdown } from "lib/markdown"

// Streams assistant chunks for a single chat into the message log.
//
// Submits the form via fetch (no full-page reload), inserts the user
// bubble immediately, shows a typing indicator while waiting for the
// first chunk, then streams chunks into a single assistant bubble.
export default class extends Controller {
  static targets = [
    "messages", "form", "input", "submitButton",
    "userTemplate", "assistantTemplate", "typingTemplate"
  ]
  static values = { id: Number, url: String }

  connect() {
    if (this.hasSubmitButtonTarget && !this.submitButtonTarget.dataset.defaultLabel) {
      this.submitButtonTarget.dataset.defaultLabel = this.submitButtonTarget.textContent.trim()
    }
    this.subscription = consumer.subscriptions.create(
      { channel: "ConversationChannel", id: this.idValue },
      { received: (data) => this.#onMessage(data) }
    )
    this.#renderExistingMarkdown()
    this.#scrollToBottom()
  }

  disconnect() {
    this.subscription?.unsubscribe()
  }

  #renderExistingMarkdown() {
    this.messagesTarget.querySelectorAll("[data-markdown='true']").forEach((bubble) => {
      const raw = bubble.dataset.raw || bubble.textContent
      setMarkdown(bubble, raw)
    })
  }

  async submit(event) {
    event.preventDefault()
    const content = this.inputTarget.value.trim()
    if (!content) return

    this.#removeEmptyState()
    this.#appendUserMessage(content)
    this.#showTyping()
    this.#setSending(true)

    try {
      const formData = new FormData(this.formElement())
      formData.set("message[content]", content)
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: { "Accept": "application/json" },
        body: formData,
        credentials: "same-origin"
      })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      this.inputTarget.value = ""
    } catch (err) {
      console.error(err)
      this.#hideTyping()
      this.#showError()
    } finally {
      this.#setSending(false)
      this.inputTarget.focus()
    }
  }

  formElement() {
    return this.hasFormTarget ? this.formTarget : this.element.querySelector("form")
  }

  #onMessage(data) {
    if (data.chunk) this.#appendChunk(data.chunk)
    if (data.tool)  this.#onToolCall()
    if (data.done)  this.#finalize()
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
    const pending = this.messagesTarget.querySelector("[data-pending]")
    pending?.removeAttribute("data-pending")
    this.#showTyping()
  }

  #finalize() {
    this.#hideTyping()
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

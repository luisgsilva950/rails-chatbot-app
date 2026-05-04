import { marked } from "marked"
import DOMPurify from "dompurify"

// Sensible defaults for streaming text from an LLM.
marked.setOptions({
  gfm: true,
  breaks: true
})

// Render Markdown to a safe HTML string.
export function renderMarkdown(text) {
  if (!text) return ""
  const raw = marked.parse(text)
  return DOMPurify.sanitize(raw, { USE_PROFILES: { html: true } })
}

// Replace the text content of a node with rendered Markdown HTML.
// Also flags the node so CSS can target rendered Markdown (e.g. to drop
// `white-space: pre-wrap`, which conflicts with block-level markup).
export function setMarkdown(node, text) {
  node.setAttribute("data-markdown", "true")
  node.innerHTML = renderMarkdown(text)
}

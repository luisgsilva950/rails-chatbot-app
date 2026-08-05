# ADR 0001 — Model-suggested choices over the SSE stream

- **Status:** Accepted
- **Date:** 2026-08-05
- **Visual version:** https://claude.ai/code/artifact/90df84ea-0a56-477e-9e2a-4cd424f3dd8d

## Context

The chat is a text pipe in both directions. The user types, the assistant
answers, and every token arrives over a single Server-Sent Events response to
`POST /chats/:chat_id/messages`. There is no element on the page the user can
interact with other than the input box.

Plenty of what this assistant asks has a small, known answer set — which
service, which of three open slots, confirm or not. Forcing those through free
text costs accuracy (typos, paraphrases the model then has to re-interpret) and
costs turns (a clarifying round trip when the answer is ambiguous).

This is also the first interactive element in the chat, so whatever shape it
takes becomes the template for the next ones: inline forms, confirmations,
attachments. The point of this record is less the buttons and more the channel
they arrive on.

## Decision

The model requests choices by **calling a tool**. `Chat::ReplyStream` — which
already owns the SSE protocol and already receives the `on_tool_call` hook —
turns that call into one more event type on the stream that is already open.

The wire protocol is now five event shapes:

```
data: {"thinking":"The user wants to book…"}
data: {"chunk":"Claro! Qual serviço você quer agendar?"}
data: {"tool":"ui--suggest_choices"}
data: {"choices":["Lavagem simples","Polimento","Higienização interna"]}
data: {"done":true}
```

The pieces:

- `Ui::SuggestChoicesTool` — the only new file under `app/`. One parameter,
  `options`, an array of 2–5 short strings. It owns `.normalize` (trim, drop
  blanks, de-duplicate, cap at `MAX_OPTIONS`), which `Chat::ReplyStream` reuses.
- `Chat::ReplyStream#write_tool_call` — writes `{"tool": …}` as before, and for
  this one tool also writes `{"choices": [...]}`.
- `chat_controller.js` — renders the options as chips. Clicking one calls the
  same `#send(content)` that the form submit calls, so the pick travels as an
  ordinary user message.

The chips are **ephemeral**: they live only in the stream. What persists is the
user's pick, as a normal `role: "user"` message — so reload, history, and the
model's own view of the conversation need no special case.

## Alternatives considered

| Option | Why not |
| --- | --- |
| **Tool call** (chosen) | Rides `on_tool_call`, which already streams. The provider validates the arguments against a JSON Schema, so the payload is either well-formed or absent. Opt-in per turn: ordinary replies are untouched. |
| Structured output / JSON mode | Forcing the whole reply into one JSON object means the text can no longer stream token by token — the product's defining behaviour traded away for a picker. |
| A marker inside the reply text (`[[choices: a\|b]]`) | Needs a parser that works across arbitrary token boundaries, and nothing stops the model from "almost" getting the syntax right. A malformed marker leaks into the user's bubble. |
| A separate endpoint the browser fetches | A second request for data the first one already had, plus a route, a lookup and server-side state to expire. Nothing is gained over putting it on the open stream. |

## Why the tool halts

A tool normally returns a result and `ruby_llm` loops: it sends the result back
to the provider for another completion. For a tool whose whole purpose is *wait
for the human*, that follow-up turn is pure cost — and it is where the model
tends to helpfully re-list the options it was just told not to repeat.

`#execute` therefore returns `halt(…)` (`RubyLLM::Tool::Halt`), which ends the
turn at the tool. That removes a provider round trip from every suggestion, and
it is also what guarantees the chips land last in the log: nothing can stream
after them, so `Chat::ReplyStream` needs no buffering to get the order right.

## Consequences

**What we get**

- One new file in `app/`. Everything else is an addition to code that already
  existed.
- Graceful degradation: if the model never calls the tool, the chat behaves
  exactly as before.
- A clicked chip is an ordinary user message, so persistence, history and the
  model's context need no special case.
- The pattern generalises — the next interactive element is another tool plus
  another event name.

**What it costs**

- The SSE protocol is now five event shapes, and it is a real contract between
  `Chat::ReplyStream` and the Stimulus controller. It belongs in `CLAUDE.md`,
  and it did not before.
- Chip labels come from the model, so they are not translatable through
  `t(…)`; the system prompt is what keeps them in pt-BR.
- The tool name is derived by `ruby_llm` from the class name
  (`Ui::SuggestChoicesTool` → `ui--suggest_choices`). A spec pins the derived
  string against `Chat::ReplyStream::CHOICES_TOOL` so a rename cannot silently
  break the event.

## Update — 2026-08-05: `choices` moved to a named `ui` event

The wire shape above (`data: {"choices": [...]}` on the default `message`
event) discriminated every event type by JSON key, mixed in with the plain
reply stream. That doesn't scale to a second widget: each one would need its
own top-level key, and the frontend would keep guessing "is this a reply
event or a widget event" from key names alone.

`choices` now streams on a separate named SSE event, so widgets are
structurally distinct from the reply stream from the first byte:

```
event: ui
data: {"type":"choices","options":["Lavagem simples","Polimento","Higienização interna"]}
```

`Chat::ReplyStream::UI_EVENT` ("ui") is the event name; `type` inside the
payload picks the widget. The next interactive element (e.g. a date picker)
adds a new `type`, not a new event name — `chat_controller.js` already
branches on `event` before touching `data`.

The `thinking` event shown in the original protocol sketch above is also
gone: `with_thinking` was dropped from `Chat::Replier`, so thought summaries
no longer stream or render. The live protocol is `chunk` / `tool` / `done`
on the default event, plus `event: ui` for widgets.

## Deliberately not done

- **Re-rendering unanswered chips after a reload.** `acts_as_chat` already
  persists the tool call and its arguments, so this stays available — it just
  needs a "no user message after this one" rule in the view, and that is not
  worth adding until someone misses it.
- **Multi-select, or labels separate from values.** No second consumer yet.
- **An `error` SSE event and rate limiting.** Both are real gaps in the app.
  Neither is this change.

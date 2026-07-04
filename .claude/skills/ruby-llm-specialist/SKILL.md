---
name: ruby-llm-specialist
description: |
  Use this skill whenever the user is reading, writing, reviewing, or
  debugging code that touches `ruby_llm` (the gem) in this repository:
  `Chat`, `Message`, `ToolCall`, `Model`, anything under `app/agents/`,
  `app/tools/`, `app/schemas/`, `app/prompts/`, the
  `config/initializers/ruby_llm.rb` initializer, controllers/POROs that
  stream LLM responses, or multi-agent orchestration code. Invoke this
  skill to **review LLM-related changes against `ruby_llm` 1.14.x best
  practices and the conventions defined in `CLAUDE.md`** for this
  chatbot. Do **not** use this skill for unrelated Rails work.
---

# Ruby LLM Specialist — Multi-agent Chatbot Reviewer

You are the in-house specialist for `ruby_llm` (1.14.x) in a Rails 8.1
chatbot built on `acts_as_chat`, HTTP + SSE streaming
(`ActionController::Live`, no background jobs, no ActionCable), and a
car-detailing domain (customers, vehicles, appointments, products,
payments).

Your job is to **review and guide** ruby_llm work — generation, edits,
and debugging. Be precise, opinionated, and short. Do not invent APIs.
When the docs disagree with what's in the repo, the docs win and you
say so explicitly.

---

## Operating contract

Before reviewing or writing ruby_llm code:

1. Read the file under review and any obviously related files
   (`Chat`, `Message`, the relevant tool/agent/schema, the calling
   controller/PORO).
2. Check `config/initializers/ruby_llm.rb` and confirm
   `config.use_new_acts_as = true`. The new association-based API is
   the only one we use.
3. Apply the **golden rules** below in order. Stop at the first
   blocker; surface it before listing nice-to-haves.

If you don't know whether an API exists, **say so and link to the
docs** — never guess. Authoritative source:
<https://rubyllm.com> (chat, tools, agents, schemas, streaming,
agentic-workflows, configuration, models, error-handling, rails).

---

## Golden rules (block on any violation)

1. **LLM calls stream through `Chat::ReplyStream`.** The reply is
   generated inside the message `POST` request and written to the SSE
   response stream (`ActionController::Live`). Controllers never call
   `chat.ask`/`complete` inline — they hand `response.stream` to
   `Chat::ReplyStream`, which delegates to `Chat::Replier`. There are
   no background jobs and no ActionCable.

2. **Single entry point per surface.** The main chat goes through
   `Chat::Replier`, which configures the persisted `Chat`
   (`with_model`, `with_instructions`, `with_tools`) and calls
   `complete`. Sub-domains go through an `Agent` subclass. Never call
   `RubyLLM.chat` ad-hoc inside business code, and **do not introduce a
   separate `Llm::Client` layer** — `acts_as_chat` is already the
   ruby_llm boundary; an extra wrapper that only forwards configuration
   is dead weight.

3. **`use_new_acts_as = true` lives in `config/application.rb`** before
   `class Application < Rails::Application`, *not* in an initializer.
   Initializers load too late for the model mixins.

4. **Never `validates :content, presence: true`** on the `Message`
   model. The assistant message starts empty during streaming;
   validation breaks `acts_as_chat`'s persistence flow.

5. **No partial-content persistence.** Don't write streamed chunks to
   the DB yourself. `acts_as_chat` upserts the assistant message on
   completion. Mid-stream, write the chunk to the SSE response stream;
   do **not** `update!(content: chunk.content)`.

6. **No prompt bodies / API responses in logs.** Tag with
   `chat_id` only. `RUBYLLM_DEBUG=true` is dev-only.

7. **Convention paths only.**
   - Tools: `app/tools/<domain>/<verb_subject>_tool.rb`
   - Agents: `app/agents/<verb_subject>_agent.rb`
   - Schemas: `app/schemas/<noun>_schema.rb`
   - Prompts: `app/prompts/<agent_path>/instructions.txt.erb`
     (snake_case of agent class name).

8. **Domain folders, not grab-bags.** A tool used by one agent lives
   under that agent's domain folder. Promote to shared only when a
   second consumer appears.

---

## Patterns we use (and their shapes)

### `Chat::Replier` (PORO, called from `Chat::ReplyStream`)

The main chat has no separate "client" layer — `acts_as_chat` is
already the ruby_llm boundary. `Chat::Replier` owns the model choice,
system instructions and default tool list directly, configures the
persisted `Chat` via the builder methods, and runs `complete`.

```ruby
class Chat::Replier
  SYSTEM_INSTRUCTIONS = "...".freeze
  DEFAULT_TOOLS = [ ... ].freeze

  def initialize(tools: DEFAULT_TOOLS, model: RubyLLM.config.default_model)
    @tools = tools
    @model = model
  end

  def call(chat, on_tool_call: nil, &on_chunk)
    return unless chat.messages.where(role: "user").exists?

    chat.on_tool_call(&on_tool_call) if on_tool_call
    chat
      .with_model(@model)
      .with_instructions(SYSTEM_INSTRUCTIONS)
      .with_tools(*@tools)
      .complete(&on_chunk)
  end
end
```

Why no `Llm::Client`? Because a wrapper that only forwards
`with_model/with_instructions/with_tools/complete` to the chat is pure
indirection — there is no HTTP client or SDK layer below it for the
wrapper to abstract. `acts_as_chat` *is* that layer.

For sub-domains with non-trivial reasoning (e.g. weather), use a
`RubyLLM::Agent` subclass instead — see "Agent" below.

### `Chat::ReplyStream`

```ruby
class Chat::ReplyStream
  def initialize(replier: Chat::Replier.new)
    @replier = replier
  end

  def call(chat, io)
    sse = ActionController::Live::SSE.new(io)
    stream_reply(chat, sse)
    sse.write(done: true)
  ensure
    sse.close
  end
end
```

The controller (`MessagesController#create`, with
`ActionController::Live`) creates the user message, sets the SSE
headers, and hands `response.stream` to `Chat::ReplyStream`. The user
message is persisted before streaming starts; the assistant message is
upserted by `acts_as_chat` on completion. If a run fails, the stream
closes without a `done` event and the client finalizes on stream end;
surface failures to the UI as a friendly pt-BR string.

### Tool

```ruby
# app/tools/scheduling/list_appointments_today_tool.rb
class Scheduling::ListAppointmentsTodayTool < RubyLLM::Tool
  description "Lista os agendamentos de hoje na estética."

  params do
    string :status, required: false,
           enum: %w[scheduled in_progress completed canceled no_show],
           description: "Filtra por status. Vazio retorna todos."
  end

  def execute(status: nil)
    scope = Appointment.on_date(Time.zone.today)
    scope = scope.where(status: status) if status.present?
    scope.includes(:customer, :vehicle, :service_type).map { |a| serialize(a) }
  rescue ActiveRecord::ActiveRecordError => e
    { error: "Falha ao consultar agendamentos: #{e.class}" }
  end

  private

  def serialize(a) = { id: a.id, customer: a.customer.name, ... }
end
```

Rules:
- `description` is in pt-BR (user-facing tone), but **identifiers stay
  in English** (CLAUDE.md).
- Return value is a Hash/Array of primitives. Never AR objects.
- Recoverable failure → `{ error: "..." }`. Unrecoverable → `raise`.
- Reads only. Mutating tools require an explicit confirmation pattern.

### Agent

```ruby
# app/agents/scheduling_agent.rb
class SchedulingAgent < RubyLLM::Agent
  chat_model Chat
  model "gpt-5-nano"
  instructions # → app/prompts/scheduling_agent/instructions.txt.erb
  tools Scheduling::ListAppointmentsTodayTool,
        Scheduling::FindCustomerByPhoneTool
end
```

### Schema

```ruby
# app/schemas/appointment_quote_schema.rb
class AppointmentQuoteSchema < RubyLLM::Schema
  string :service_name
  number :price_cents
  integer :duration_minutes
  array :upsells do
    string
  end
end
```

---

## Multi-agent orchestration

`ruby_llm` does **not** ship handoff or shared-memory primitives. We
implement coordination explicitly. Pick the simplest pattern that
solves the problem:

- **Sequential**: `out = AgentA.new.ask(x).content; AgentB.new.ask(out)`.
  Default for "research → summarize" pipelines.
- **Routing**: a small classifier picks which specialist to dispatch.
  Use a hash lookup, not a `case`.
- **Agents-as-tools**: an orchestrator agent registers a
  `DelegateTool` whose `#execute` calls a sub-agent's `Chat` and
  returns `halt(result)` so the orchestrator doesn't re-summarize.
- **Parallel fan-out**: only when latency matters. `async` gem,
  `task.async { Agent.new.ask(...) }`, then `wait`.
- **Evaluator–optimizer**: draft + critic loop, max 3 rounds.

For our chatbot, the canonical layout is one **router agent** that
dispatches to specialists by domain (Scheduling, Inventory, Cash Flow,
Customer Lookup). Each specialist has its own tools.

---

## Streaming + SSE

- `complete(&block)` runs inside the message `POST` request, driven by
  `Chat::ReplyStream` (`ActionController::Live`).
- Write `chunk.content` only when present (early chunks may carry
  metadata only).
- Events are JSON over SSE (`{"thinking": ...}`, `{"chunk": ...}`,
  `{"tool": ...}`, `{"done": true}`); SSE is ordered by design — no
  client-side reordering needed.
- Thinking is enabled via `with_thinking(budget:)` in `Chat::Replier`;
  thought summaries arrive on `chunk.thinking&.text` and the full text
  is persisted by `acts_as_chat` in `Message#thinking_text`.
- Always close the response stream in an `ensure` — a leaked stream
  pins a Puma thread.
- Don't update the message row mid-stream. The final upsert by
  `acts_as_chat` is the source of truth.

---

## Configuration checklist

In [`config/initializers/ruby_llm.rb`](config/initializers/ruby_llm.rb):

- API keys come from `Rails.application.credentials` or ENV. Never
  literal.
- `config.default_model` is set explicitly. Don't rely on the gem's
  default — it changes between releases.
- `config.logger = Rails.logger`.
- Connection: `config.request_timeout`, `config.max_retries`,
  `config.retry_backoff_factor` set to values matching our chat SLA.
- `config.openai_use_system_role = true` if/when we point at an
  OpenAI-compatible proxy.

In [`config/application.rb`](config/application.rb): `use_new_acts_as
= true` before `class Application < Rails::Application`.

Run `bin/rails ruby_llm:load_models` after upgrading the gem to
refresh the `models` table.

---

## Review checklist (use this on every PR touching ruby_llm)

- [ ] `config.use_new_acts_as = true` set in `config/application.rb`?
- [ ] No `validates :content, presence: true` on `Message`?
- [ ] All LLM calls go through `Chat::Replier` (main chat, streamed by
      `Chat::ReplyStream`) or an `Agent` (sub-domains)?
- [ ] No new `Llm::Client`-style wrapper that just forwards to
      `acts_as_chat`?
- [ ] Controller has zero LLM logic (it only hands `response.stream`
      to `Chat::ReplyStream`)?
- [ ] Streaming block guards against `chunk.content.blank?` before
      writing to the stream?
- [ ] SSE stream closed in an `ensure`?
- [ ] No mid-stream `Message#update!` of `content`?
- [ ] Tools return primitives (`Hash`/`Array`/`String`), not AR
      objects?
- [ ] Tool errors return `{ error: "..." }` for recoverable cases?
- [ ] Tool params use the v1.9+ `params do ... end` DSL with explicit
      types and pt-BR `description`s?
- [ ] Schemas under `app/schemas/`, agents under `app/agents/`, tools
      under `app/tools/<domain>/`, prompts under
      `app/prompts/<agent_path>/instructions.txt.erb`?
- [ ] No prompt body / response body / API key in logs?
- [ ] Errors caught with the right `RubyLLM::*Error` subclass — never
      `rescue Exception`, never `rescue StandardError` swallowing
      everything silently?
- [ ] Tests in place: model spec for AR side, tool spec for `#execute`
      logic, request/PORO spec for the SSE orchestration, **VCR
      cassette** (with API key filter) for the actual LLM call?
- [ ] 100% line + branch coverage on new/changed code (CLAUDE.md
      mandate)?
- [ ] User-facing strings (descriptions visible to users, error
      surfaces) in pt-BR via `t(...)`; identifiers in English?
- [ ] If multi-agent: orchestration pattern is the simplest one that
      works (no `Async` unless latency requires it; no agents-as-tools
      unless the orchestrator genuinely needs to reason about the
      sub-agent's output)?

---

## Common bugs to look for

- **Silent assistant-message destruction**: a failure inside `ask`
  destroys the placeholder assistant message. If you see "the message
  disappeared", check for an exception swallowed in the streaming
  request.
- **Tool execute kwargs not matching params**: `params do string :x
  end` requires `def execute(x:)`. Mismatch crashes at call time.
- **Missing `provider:` with `assume_model_exists`**: required, or it
  raises `ModelNotFoundError`.
- **n+1 on chat render**: always `Chat.includes(:messages)` (and
  `messages.includes(:tool_calls)` when relevant).
- **Out-of-order chunks** under load → fix client-side, not by
  serializing the stream.
- **Gemini empty messages**: provider rejects them. Strip whitespace
  before `ask`.
- **Anthropic prompt caching** uses `content_raw` JSONB. Don't drop
  that column from migrations.
- **Integer-backed enums** in any new migration. Forbidden by
  CLAUDE.md — strings only.

---

## Chat vs Agent — practical differences

`RubyLLM::Agent` is **declarative sugar over `RubyLLM::Chat`**. There is
no capability gap. Internally, calling `agent.ask(...)` builds a fresh
`Chat` from the agent's class-level config (`model`, `instructions`,
`tools`) and runs `complete`. Tool loop, streaming, schemas — all
identical.

What actually differs in practice:

| Aspect              | `Chat` (with `acts_as_chat`)        | `Agent` (in-memory)            |
| ------------------- | ----------------------------------- | ------------------------------ |
| Persistence         | AR — survives across requests       | Lives only inside one call     |
| History             | Accumulates the whole conversation  | Starts from zero on every ask  |
| Tool loop           | Identical                           | Identical                      |
| Streaming           | Same `complete(&block)` API         | Same                           |
| Reuse between calls | The whole point                     | Stateless by design            |
| Audit trail         | Full (messages + tool_calls in DB)  | None unless you log explicitly |

**Rule of thumb:**
- The **main user-facing chat** is always a persisted `Chat` with
  `acts_as_chat`. Only one of these per conversation.
- **Sub-domains** (weather, help center, etc.) become an **`Agent`
  invoked from a tool** when their reasoning is non-trivial; otherwise
  they stay as plain tools.

### "Why not just use a thin Chat with everything as agent-as-tool?"

Tempting, and it works, but the trade-offs are real:

**Pros:** encapsulation per domain, smaller main system prompt (saves
tokens on every turn), domain-specific model choice, easier domain
testing.

**Cons:** every agent-as-tool call adds **2 extra LLM turns** (wrapper
in, wrapper out) — that is real latency and real money. Sub-agents
also lose the user's full context: they only see whatever the main
chat decides to pass as arguments. Debugging is harder because the
sub-agent's internal turns aren't in the persisted `Chat`.

**Use agent-as-tool when:**
- The domain coordinates **multiple of its own tools** in sequence
  (e.g. `WeatherAgent` decides historical vs forecast and wraps the
  forecast tool with date interpretation rules).
- The domain has **strong reasoning rules** that don't fit cleanly in
  the main system prompt.
- You want to **isolate the context** for compliance / multi-tenant
  reasons.

**Use a plain tool (no agent) when:**
- It's a **single, well-defined operation** (lookup, sum, search).
- The user's question is already a usable input.
- No multi-step reasoning between calls.

In this repo, `Weather::AskAgentTool` → agent-as-tool is justified.
`Scheduling::*`, `Inventory::*`, `CashFlow::*`, `CustomerLookup::*`
are plain tools and should stay that way.

---

## System instructions — rules that stuck

The `Chat::Replier::SYSTEM_INSTRUCTIONS` is the single source of truth
for the main chat's behavior. Reviewing or editing it, enforce:

- **Forbid "I'll check / I'm looking up" without a tool call.** Gemini
  2.5 Flash in particular sometimes ends a turn announcing a tool
  without actually emitting `function_call`. The system prompt must
  explicitly ban that pattern.
- **Tool descriptions cost tokens on every turn.** They're sent with
  every request as part of the tool schema. Keep them tight — one
  short sentence per tool. No examples in the description; put
  examples in the agent's `instructions` if needed.
- **Dynamic context belongs in instructions, not in mock data.** A
  weather/scheduling agent gets `today: Date.current.iso8601`
  injected into its instructions template. Do **not** dump the data
  range of the underlying source ("we have data from X to Y") —
  let the tool surface that when called.
- **Cross-domain coordination is the main chat's job.** When two
  domains need to be combined ("compare weather vs sales"), the main
  chat orchestrates by calling each tool/agent with the right
  arguments. Sub-agents don't reach across domains.

---

## Empty assistant messages

A turn that consists only of `tool_calls` produces a `Message` with
`role: "assistant"` and **empty `content`**. This is correct and must
be preserved in the DB — `ruby_llm` reconstructs the chat history from
those rows on every subsequent `complete`, and it needs the tool_call
record to know what was already requested.

Do **not** delete or skip these messages. Filter them at the **view
layer** instead:

```erb
<%= render @chat.messages.where.not(content: [ nil, "" ]) %>
```

The `validates :content, presence: true` golden rule already prevents
the simpler footgun (validation failing the empty-content row). This
is the rendering complement.

---

## Tool-call typing indicator

`acts_as_chat` exposes lifecycle callbacks on the chat instance:
`on_new_message`, `on_end_message`, `on_tool_call`, `on_tool_result`.

For the "Pensando..." UX during tool execution, `Chat::Replier`
accepts an `on_tool_call:` keyword and registers it via
`chat.on_tool_call(&on_tool_call)`. `Chat::ReplyStream` writes
`{ tool: tool_call.name }` as an SSE event and the Stimulus
controller closes any pending bubble and re-shows the typing
indicator.

Do **not** poll the DB for tool-call state. The callback is
authoritative and runs in the same request as the streaming loop.

---

## Embeddings & RAG

`RubyLLM.embed(text, model:, dimensions:)` returns an `Embedding`
with `vectors`, `model`, `input_tokens`. Multi-text input (Array) is
batched in a single request — always batch when you can.

### Stack for this repo (when we add it)

- **Postgres + pgvector** — same primary DB, no extra service. The
  base image must be `pgvector/pgvector:pg16` (or the extension
  installed manually); `postgres:16` does **not** ship pgvector.
- **`neighbor` gem** — provides `has_neighbors :embedding` and
  `nearest_neighbors(:embedding, vec, distance: :cosine)`. Without it
  you fight pgvector's string casts.
- **Embedding model independent from chat model.** Mix freely.
  `text-embedding-3-small` (OpenAI, 1536d, cheap) or
  `text-embedding-004` (Gemini) are sane defaults. Pin via
  `config.default_embedding_model`.

### Indexing rules

- **Embed `title + "\n\n" + body`**, not body alone — titles carry
  strong semantic keywords.
- **Embed the user query raw**, no "represent this for retrieval"
  prefix. Modern models don't need it.
- Generate the embedding `before_save :generate_embedding,
  if: :will_save_change_to_body?`. Only move to a job if it becomes a
  write-path bottleneck (rare for a small catalog).
- Store the **embedding model name** alongside the vector so a
  provider/model swap can be detected — vector spaces are not
  cross-compatible.
- Index: `using: :hnsw, opclass: :vector_cosine_ops`. Don't bother
  with `ivfflat` for this scale.
- **Multi-DB: vectors live only in `primary`.** Never in the cache
  schema.

### Retrieval rules

- `nearest_neighbors` always returns top-N regardless of relevance.
  **Apply a distance threshold** (cosine `< ~0.5–0.6`) before
  returning to the LLM, otherwise it gets junk and synthesizes
  nonsense.
- Default `limit: 3`. More than that bloats the next LLM turn for no
  retrieval gain.
- Return `{ results: [{ title, slug, excerpt }] }` — never AR objects.

### Architectural fit: tool, not agent

For a help-center / FAQ over how-tos, the right shape is a **plain
tool**: `HelpCenter::SearchHowTosTool`. Single operation
(`embed → nearest_neighbors → top-K`), no multi-step reasoning. Don't
wrap it in an agent unless you actually need query reformulation,
category navigation, or cross-document synthesis as a separate
reasoning loop.

When the tool is added, also append a short note to
`Chat::Replier::SYSTEM_INSTRUCTIONS` instructing the model to use it
for "como faço X / onde altero Y" questions — without the nudge,
models often answer from generic knowledge and skip the help center.

### Hybrid search & chunking — defer

- **Chunking**: only when documents exceed ~1k tokens or retrieval
  starts missing within-document specifics. Start whole-document.
- **Hybrid (embeddings + tsvector)**: only when embedding-only
  retrieval misses on exact technical terms (codes, menu names).
  Reciprocal Rank Fusion is the standard combiner. YAGNI until
  failure cases show up.

---

## Authoritative references

- Chat & ask: <https://rubyllm.com/chat/>
- Streaming: <https://rubyllm.com/streaming/>
- Tools: <https://rubyllm.com/tools/>
- Agents: <https://rubyllm.com/agents/>
- Agentic workflows: <https://rubyllm.com/agentic-workflows/>
- Schemas: <https://rubyllm.com/chat/#getting-structured-output>
- Rails integration: <https://rubyllm.com/rails/>
- Configuration: <https://rubyllm.com/configuration/>
- Models: <https://rubyllm.com/models/>
- Errors: <https://rubyllm.com/error-handling/>
- Source: <https://github.com/crmne/ruby_llm>

When in doubt, fetch the doc page above and quote it. Don't paraphrase
APIs from memory.

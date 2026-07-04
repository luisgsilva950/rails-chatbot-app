# Rails Chatbot App — AI Context

## Project Brief

A simple, well-built **chatbot** powered by `ruby_llm`. The user opens a
page, types a message, and watches the assistant's reply stream back token
by token over **HTTP + Server-Sent Events (SSE)**. Conversations are
persisted so the user can come back and pick up where they left off.

That's the whole product. No multi-tenancy, no payments, no admin
dashboard, no agents-with-tools layer. **One thing, done well.**

**Tone:** clear, direct, helpful. The chatbot is a tool, not a personality.

**Language:** all user-facing strings in **pt-BR**. All code, schema,
identifiers, and commit messages in English. No exceptions.

---

## Stack

| Layer        | Technology                                                |
| ------------ | --------------------------------------------------------- |
| Backend      | Ruby on Rails 8.1, Ruby 3.4.2                             |
| Database     | PostgreSQL 16 (multi-db: primary + cache)                 |
| Cache        | Solid Cache                                               |
| Realtime     | HTTP + SSE via `ActionController::Live` (chat streaming)  |
| Frontend     | ERB + Hotwire (Turbo + Stimulus) via importmap            |
| Styling      | Plain CSS in `app/assets/stylesheets/` — small and boring |
| LLM          | `ruby_llm` (provider-agnostic; configured per env)        |
| Testing      | RSpec, FactoryBot, VCR, WebMock                           |
| Deploy       | Kamal 2 + Docker                                          |
| Local dev    | `docker compose up -d` (Postgres) + `bin/dev`             |

No React. No Vite. No Tailwind. No Sidekiq/Redis. No ActionCable. No
background jobs — the reply streams inside the request. No OmniAuth/Pundit
until a real auth requirement appears. Add a tool only when the **second
consumer** appears.

---

## Core Philosophy

Three references guide every decision:

- **Sandi Metz** — small classes, single responsibility, simple OO.
- **Avdi Grimm** — confident code that doesn't hesitate. Convert at
  boundaries, fail explicitly, never silently return nil.
- **DHH** — Convention over Configuration. Use Rails the way it was
  designed. Resist the temptation to abstract too early.

The golden rule: **simplicity above all**. Every decision must pass YAGNI
and KISS. If a solution feels complicated, it's probably wrong. This is a
chatbot — keep it that way.

---

## Engineering Mindset

Think like a **principal engineer**: choose the simplest thing that solves
the problem. Clever code is not good code — clear code is good code.

### Plan before you code

For anything beyond a trivial change, plan first. Break it into small,
concrete steps. If the plan looks complex, simplify before writing code.

### Prefer model validations — always

Data integrity belongs in the model, not in POROs or controllers.

```ruby
class Message < ApplicationRecord
  belongs_to :conversation

  ROLES = %w[user assistant system].freeze

  validates :role,    presence: true, inclusion: { in: ROLES }
  validates :content, presence: true
end
```

### Eliminate conditional complexity

Avoid `if/else` chains. Prefer:

1. **Guard clauses** — return early, keep the happy path flat.
2. **Polymorphism** — replace conditionals with objects sharing an interface.
3. **Hash lookups / constants** — replace `if/elsif` chains with mappings.
4. **ActiveRecord scopes and validations** — let the framework do the work.
5. **Default values** — eliminate nil checks with sensible defaults.

```ruby
# Good
def call(message)
  return unless message.user?

  reply_to(message)
end
```

### When in doubt, simplify

- If a method needs an `else`, question whether the `if` is necessary.
- If a class needs more than one public method, question whether it's doing too much.
- If a feature requires more than 3 new files, question the approach.
- If you can't explain the solution in one sentence, it's too complex.

---

## Sandi Metz's Rules

1. **Classes ≤ 100 lines.**
2. **Methods ≤ 5 lines.**
3. **Methods take ≤ 4 parameters** (a hash counts as one).
4. **Controllers: a single instance variable passed to the view.**

Breaking a rule requires an explicit, justified comment.

---

## SOLID

SRP and DIP matter most.

### Single Responsibility

- **Models:** validations, associations, scopes, enums. Nothing else.
- **Controllers:** receive request → delegate → respond (or stream).
- **POROs:** one business operation, one public method (`#call`).
- **Views/partials:** presentation only.

### Dependency Inversion

High-level code depends on abstractions, not concrete implementations. Pass
collaborators in the constructor with sensible defaults so tests can swap
them.

```ruby
class Chat::Replier
  def initialize(tools: DEFAULT_TOOLS, model: RubyLLM.config.default_model)
    @tools = tools
    @model = model
  end

  def call(chat, &on_chunk)
    chat
      .with_model(@model)
      .with_instructions(SYSTEM_INSTRUCTIONS)
      .with_tools(*@tools)
      .complete(&on_chunk)
  end
end
```

---

## Confident Code (Avdi Grimm)

### Convert at the boundary

Validate and normalize input where it enters the system. Inside, trust it.

### Never return nil silently

Use exceptions, NullObject, or a sensible default — but don't hand back
`nil` and hope.

### Guard clauses over nesting

```ruby
def stream(conversation)
  return if conversation.discarded?
  return if conversation.messages.empty?

  perform_stream(conversation)
end
```

---

## Architectural Rules

### Controllers

- Thin: fetch data → delegate → render. ~5 lines per action.
- Stick to RESTful actions. Add custom actions only when truly needed.
- Never put business logic in `before_action`.

```ruby
class MessagesController < ApplicationController
  include ActionController::Live

  def create
    @chat.messages.create!(role: "user", content: message_params[:content])
    prepare_sse_headers
    Chat::ReplyStream.new.call(@chat, response.stream)
  end
end
```

### Models

- Embrace Active Record: validations, associations, scopes, enums.
- **Always prefer model validations.**
- **Callbacks scoped to the aggregate root only.** A `Message` callback
  may touch its `Conversation`. It must **not** call the LLM, send email,
  or trigger unrelated side effects.
- Cross-cutting side effects (LLM calls, streaming) → **explicit calls
  in the controller, delegated to a PORO**.

### Business logic extraction

When logic outgrows the model or controller, extract a PORO under
`app/services/`, organized by domain (`app/services/chat/`,
`app/services/llm/`).

- Single public entry point: `#call`.
- `VerbSubject` naming: `Chat::Replier`, `Chat::ReplyStream`.
- Receive collaborators in the constructor (kw args + defaults).

### Streaming (HTTP + SSE)

- There are **no background jobs and no ActionCable**. The assistant
  reply is generated inside the `POST /chats/:chat_id/messages` request
  and streamed to the client as Server-Sent Events via
  `ActionController::Live`.
- `Chat::ReplyStream` owns the SSE protocol: it wraps the response
  stream in `ActionController::Live::SSE`, forwards content chunks and
  tool-call events from `Chat::Replier`, emits a final `done` event, and
  **always closes the stream** in an `ensure`.
- Each event is a small JSON object: `{"chunk": "..."}`,
  `{"tool": "..."}`, `{"done": true}`.
- The controller only creates the user message, sets the SSE headers
  (`Content-Type: text/event-stream`, `Cache-Control: no-cache`,
  `X-Accel-Buffering: no`), and hands `response.stream` to
  `Chat::ReplyStream` — no LLM logic inline.
- A streaming request holds a Puma thread until the reply finishes.
  Size `RAILS_MAX_THREADS` with that in mind.

### Routing

- RESTful. Prefer `resources` and `resource`.
- Messages are **nested under conversations** — they have no identity
  outside one.
- Max 2 levels of nesting.

---

## Frontend Conventions (deliberately small)

The frontend is **just enough** to send a message and watch the reply
stream in. Keep it that way.

- ERB views in `app/views/`.
- One Stimulus controller per interactive piece (e.g.
  `chat_controller.js`): submit the form, append streamed chunks to the
  DOM, autoscroll.
- Turbo for navigation; the live token stream is read with `fetch` from
  the SSE response of the message `POST` (no ActionCable, no
  `EventSource`).
- Plain CSS in `app/assets/stylesheets/`. Small files. No design system,
  no component library, no preprocessor pipeline beyond Propshaft.
- Accessibility basics: labelled form, `role="log"` for the message list,
  visible focus states.

If you're tempted to add a frontend framework, an SPA router, or a build
tool — stop. The product doesn't need it.

---

## LLM Conventions (`ruby_llm`)

- **The main chat goes through `Chat::Replier`**, which owns the model
  choice, system instructions, and default tool list, and calls
  `complete` on the persisted `Chat`. `acts_as_chat` is the ruby_llm
  boundary — there is no separate `Llm::Client` wrapper.
- **Invoked from the request through `Chat::ReplyStream`**, which writes
  the reply to the SSE response stream — never called directly from a
  controller action body.
- `acts_as_chat` persists every assistant message (`role: "assistant"`,
  content, token usage if available) once on completion.
- **Streaming:** `Chat::ReplyStream` yields chunks from `Chat::Replier`
  and writes each one as an SSE event. The full message is saved once on
  completion — never persist partial content mid-stream.
- Errors are caught, logged (without prompt body), and surfaced to the
  UI as a friendly pt-BR string.
- API keys live in **encrypted credentials** or environment variables.
  Never in source.

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

---

## Data Modeling

### Language

- **All schema, code, and identifiers in English.**
- **All user-facing strings in pt-BR via `t('…')`.** Never hardcode user
  strings.

### Schema

- Snake_case plural tables. Snake_case columns.
- Timestamps on every table.
- `null: false` wherever the domain demands it.
- Foreign keys at the DB level (`foreign_key: true`).
- Indexes on FKs and on columns used in `WHERE` / `ORDER BY`.
- Use JSONB for flexible payloads (e.g. `Message#metadata` for token
  usage or tool calls if/when they appear).

### Enums

Enums must be **explicit, readable strings — never integers**. Reading a
row in `psql` should tell you what the value means without consulting Ruby.

- The DB column is `string`, `null: false`, with a `CHECK` constraint or
  Postgres native `ENUM` type listing every allowed value.
- The Rails enum maps each symbol to its **string** backing.
- Constants list the values in one place; the enum and the validation read
  from that constant.
- Add an index on the column when it's used in `WHERE`/`ORDER BY`.

```ruby
# Migration
class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.string  :role,    null: false
      t.string  :status,  null: false, default: "pending"
      t.text    :content, null: false
      t.timestamps
    end

    add_check_constraint :messages,
      "role IN ('user','assistant','system')",
      name: "messages_role_check"

    add_check_constraint :messages,
      "status IN ('pending','streaming','completed','failed')",
      name: "messages_status_check"

    add_index :messages, :status
  end
end
```

```ruby
# Model
class Message < ApplicationRecord
  ROLES    = %w[user assistant system].freeze
  STATUSES = %w[pending streaming completed failed].freeze

  enum :role,   ROLES.index_with(&:itself)
  enum :status, STATUSES.index_with(&:itself), default: "pending"

  validates :role,   presence: true, inclusion: { in: ROLES }
  validates :status, presence: true, inclusion: { in: STATUSES }
end
```

`ROLES.index_with(&:itself)` produces `{ "user" => "user", ... }`, which
makes Rails store the literal string. Never write `enum :role, %i[user
assistant system]` — that maps to integers (`0`, `1`, `2`) and ruins
auditability.

For sets that change rarely and need DB-level enforcement, prefer a
**Postgres native `ENUM` type** over a `CHECK` constraint:

```ruby
def up
  create_enum :message_role, %w[user assistant system]
  add_column :messages, :role, :message_role, null: false
end
```

### Multi-database (gotcha)

The Solid stack runs on **separate Postgres databases per role**
(primary, cache). After any change to `db/cache_schema.rb`, run
`bin/rails db:prepare`. If Solid Cache tables are missing, that's the
fix.

---

## Security

- Don't log message content or LLM prompts/responses verbatim. Tag logs
  with `conversation_id` only.
- Rate-limit message creation per IP / conversation (Rails 8
  `rate_limit`).
- CSRF tokens on every form. The SSE stream is the response to the
  authenticated message `POST` — same session/cookie, same CSRF check.
- LLM provider API keys via `Rails.application.credentials` or ENV.
  Never hardcoded, never in logs.
- Sanitize what you render. The chatbot's reply is **plain text** by
  default; if Markdown is rendered, render it through a safe pipeline.

---

## Testing

**Test behavior, not implementation.** Integration tests are the default.

### Mandatory

- Every change ships with tests.
- **100% line and branch coverage on every feature.** Measured with
  `simplecov` and enforced in CI.
- Untestable code is a design smell — refactor until it's testable.
- Truly uncoverable code carries an explicit `# :nocov:` block with a
  one-line justification. Reviewed case by case.
- Bug fixes start with a regression test that fails before the fix.

### Principles

- **RSpec.** Do not introduce Minitest.
- Tests hit a **real Postgres**. Never mock Active Record.
- Mock only **external boundaries** — the LLM provider. Use VCR
  cassettes filtered for API keys.
- Use FactoryBot factories. Keep them minimal.
- Tests are independent — no order dependencies, no shared mutable
  state.

### Layers (in order of preference)

1. **Request specs** — primary layer. Happy path (including the SSE
   body) + validation failure + rate-limit / auth where applicable.
2. **Model specs** — validations, scopes, instance methods.
3. **PORO specs** — `Chat::ReplyStream`, `Chat::Replier` (with VCR for
   the LLM call).
4. **System specs** — Capybara for one golden path: send a message, see
   the streamed reply appear.

---

## What NOT to do

| Anti-pattern                              | Why                                                                 |
| ----------------------------------------- | ------------------------------------------------------------------- |
| Service objects for trivial CRUD          | Indirection with no value.                                          |
| Callbacks triggering external effects     | Hidden, untestable, ordering nightmares.                            |
| LLM logic inline in a controller          | Controllers orchestrate. Logic lives in a PORO (`Chat::ReplyStream`). |
| Sidekiq, Solid Queue, ActionCable         | The reply streams inside the request over SSE. No async pipeline.  |
| Hardcoded user strings                    | Always `t("...")`, even with one locale.                            |
| Tailwind, shadcn, styled-components       | Not part of this stack. Plain CSS only.                             |
| React, Vite, SPA routers                  | Not needed. ERB + Hotwire is enough.                                |
| Service objects without `#call`           | Single public entry point keeps POROs honest.                       |
| `app/services/` grab-bag                  | Use domain-named subfolders (`chat/`, `llm/`).                      |
| Non-English schema/code                   | Codebase must be universally readable.                              |
| `rescue Exception`                        | Use `rescue StandardError` or specific exceptions.                  |
| Logging full prompts/responses            | Privacy + cost noise. Log IDs and metadata only.                    |
| API keys in source                        | Credentials or ENV — always.                                        |
| Adding gems "we might need"               | Wait until the second consumer appears.                             |
| Integer-backed enums in the DB            | Always store the literal string. See the Enums section.             |

---

## Naming

- Classes: nouns or `VerbSubject` for POROs (`Chat::Replier`,
  `Chat::ReplyStream`).
- Methods: descriptive verbs.
- Variables: descriptive. No abbreviations.
- Scopes: composable (`recent`, `with_pending_reply`).
- No `get_` / `set_` prefixes — Ruby doesn't use them.

---

## i18n

- Every user-facing string goes through `t("...")` and lives in
  `config/locales/pt-BR.yml`.
- Tone: clear, direct, helpful. No forced legalese, no slang.
- Keep keys nested by feature: `conversations.created`, `messages.failed`.

---

## RuboCop

- `rubocop-rails-omakase` is the base style.
- **Zero offenses required** — enforced in CI.
- Disable rules only with an explicit, justified `# rubocop:disable`
  comment.
- Run `bin/rubocop -A` to autocorrect safe offenses.

---

## Common commands

```bash
bin/setup                            # idempotent dev setup
bin/dev                              # dev server (Puma)
docker compose up -d                 # Postgres

bundle exec rspec                    # all tests
bundle exec rspec spec/requests/...  # one suite
bin/rubocop -A                       # autocorrect Ruby style

bin/rails db:prepare                 # idempotent: creates DBs + loads schemas
bin/rails db:reset                   # drop + create + migrate + seed
bin/rails console
```

---

## PR checklist

- [ ] Single responsibility per class?
- [ ] Classes ≤ 100 lines, methods ≤ 5 lines?
- [ ] Controllers thin (≤ 5 lines per action, one ivar to the view)?
- [ ] Business logic in POROs, not controllers?
- [ ] Validations on the model — not in POROs / controllers?
- [ ] LLM called only through `Chat::Replier` (main chat, streamed by
      `Chat::ReplyStream`) or an `Agent` (sub-domain)?
- [ ] Strings in `pt-BR.yml`, accessed via `t(...)`?
- [ ] Request / PORO specs cover happy path + failure?
- [ ] **100% line + branch coverage on new/changed code** (`simplecov`)?
- [ ] No mocks for Active Record? VCR for the LLM provider only?
- [ ] `bin/rubocop` passes with zero offenses?
- [ ] No prompt content / response bodies in logs?

# Rails Chatbot App — AI Context

## Project Brief

A simple, well-built **chatbot** powered by `ruby_llm`. The user opens a
page, types a message, and watches the assistant's reply stream back token
by token over **ActionCable**. Conversations are persisted so the user can
come back and pick up where they left off.

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
| Database     | PostgreSQL 16 (multi-db: primary + cache + queue + cable) |
| Background   | Solid Queue                                               |
| Cache        | Solid Cache                                               |
| Realtime     | Solid Cable + ActionCable (chat streaming)                |
| Frontend     | ERB + Hotwire (Turbo + Stimulus) via importmap            |
| Styling      | Plain CSS in `app/assets/stylesheets/` — small and boring |
| LLM          | `ruby_llm` (provider-agnostic; configured per env)        |
| Testing      | RSpec, FactoryBot, VCR, WebMock                           |
| Deploy       | Kamal 2 + Docker                                          |
| Local dev    | `docker compose up -d` (Postgres) + `bin/dev`             |

No React. No Vite. No Tailwind. No Sidekiq/Redis. No OmniAuth/Pundit until
a real auth requirement appears. Add a tool only when the **second
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

  Chat::ReplyJob.perform_later(message.id)
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
- **Controllers:** receive request → delegate → respond.
- **Channels:** subscribe/unsubscribe and broadcast. No business logic.
- **POROs:** one business operation, one public method (`#call`).
- **Views/partials:** presentation only.

### Dependency Inversion

High-level code depends on abstractions, not concrete implementations. Pass
collaborators in the constructor with sensible defaults so tests can swap
them.

```ruby
class Chat::Replier
  def initialize(llm: Llm::Client.new)
    @llm = llm
  end

  def call(conversation, &on_chunk)
    @llm.stream(conversation.messages_for_llm, &on_chunk)
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
  def create
    @message = @conversation.messages.create!(message_params.merge(role: "user"))
    Chat::ReplyJob.perform_later(@message.id)
    redirect_to @conversation
  end
end
```

### Models

- Embrace Active Record: validations, associations, scopes, enums.
- **Always prefer model validations.**
- **Callbacks scoped to the aggregate root only.** A `Message` callback
  may touch its `Conversation`. It must **not** call the LLM, send email,
  or enqueue jobs for unrelated concerns.
- Cross-cutting side effects (LLM calls, broadcasts) → **explicit calls
  in the controller, channel, or job**.

### Business logic extraction

When logic outgrows the model or controller, extract a PORO under
`app/services/`, organized by domain (`app/services/chat/`,
`app/services/llm/`).

- Single public entry point: `#call`.
- `VerbSubject` naming: `Chat::Replier`, `Chat::ReplyJob`.
- Receive collaborators in the constructor (kw args + defaults).

### Background jobs

- All LLM calls go into Solid Queue jobs. **Never call the LLM from a
  request thread.**
- Jobs **must be idempotent** — they will retry.
- Jobs are thin: they call a model or PORO, they don't contain business
  logic.

### Channels (ActionCable)

- One channel per resource: `ConversationChannel` streams a single
  conversation.
- Authorize on `subscribed` (`reject` if the visitor doesn't own the
  conversation).
- The job streams chunks via `ConversationChannel.broadcast_to` —
  channels themselves do not call the LLM.

```ruby
class ConversationChannel < ApplicationCable::Channel
  def subscribed
    conversation = Conversation.find_by(id: params[:id])
    return reject unless conversation

    stream_for conversation
  end
end
```

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
- Turbo for navigation; ActionCable (consumer in
  `app/javascript/channels/`) for the live token stream.
- Plain CSS in `app/assets/stylesheets/`. Small files. No design system,
  no component library, no preprocessor pipeline beyond Propshaft.
- Accessibility basics: labelled form, `role="log"` for the message list,
  visible focus states.

If you're tempted to add a frontend framework, an SPA router, or a build
tool — stop. The product doesn't need it.

---

## LLM Conventions (`ruby_llm`)

- **All LLM calls go through a single client wrapper** (e.g.
  `Llm::Client`). It owns the `ruby_llm` configuration, model choice, and
  error handling.
- **Always invoked from a job**, never inline in a request.
- The job persists every assistant message (`role: "assistant"`, content,
  token usage if available).
- **Streaming:** the job yields chunks and broadcasts each one over
  `ConversationChannel`. The full message is saved once on completion.
- Errors are caught, logged (without prompt body), persisted on the
  message (`status: "failed"`, error class), and surfaced to the UI as a
  friendly pt-BR string.
- API keys live in **encrypted credentials** or environment variables.
  Never in source.

```ruby
class Chat::ReplyJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = Message.find(message_id)
    Chat::Replier.new.call(message.conversation) do |chunk|
      ConversationChannel.broadcast_to(message.conversation, chunk: chunk)
    end
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

### Multi-database (gotcha)

The Solid stack runs on **separate Postgres databases per role**
(primary, cache, queue, cable). After any change to `db/queue_schema.rb`,
`db/cache_schema.rb`, or `db/cable_schema.rb`, run
`bin/rails db:prepare`. If `solid_queue_processes` or similar tables are
missing, that's the fix.

---

## Security

- Don't log message content or LLM prompts/responses verbatim. Tag logs
  with `conversation_id` only.
- Rate-limit message creation per IP / conversation (Rails 8
  `rate_limit`).
- CSRF tokens on every form. ActionCable connections are authenticated
  by the same session/cookie.
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

1. **Request specs** — primary layer. Happy path + validation failure +
   rate-limit / auth where applicable.
2. **Channel specs** — `ConversationChannel` subscribe/reject and
   broadcast behavior.
3. **Model specs** — validations, scopes, instance methods.
4. **Job / PORO specs** — `Chat::ReplyJob`, `Chat::Replier` (with VCR
   for the LLM call).
5. **System specs** — Capybara for one golden path: send a message, see
   the streamed reply appear.

---

## What NOT to do

| Anti-pattern                              | Why                                                                 |
| ----------------------------------------- | ------------------------------------------------------------------- |
| Service objects for trivial CRUD          | Indirection with no value.                                          |
| Callbacks triggering external effects     | Hidden, untestable, ordering nightmares.                            |
| Inline LLM calls                          | Slow, non-retryable, no audit trail. Use a job.                     |
| LLM logic in a channel or controller      | Channels broadcast; controllers orchestrate. Logic lives in a PORO. |
| Hardcoded user strings                    | Always `t("...")`, even with one locale.                            |
| Tailwind, shadcn, styled-components       | Not part of this stack. Plain CSS only.                             |
| React, Vite, SPA routers                  | Not needed. ERB + Hotwire is enough.                                |
| Sidekiq / Redis                           | Solid Queue on Postgres is the choice.                              |
| Service objects without `#call`           | Single public entry point keeps POROs honest.                       |
| `app/services/` grab-bag                  | Use domain-named subfolders (`chat/`, `llm/`).                      |
| Non-English schema/code                   | Codebase must be universally readable.                              |
| `rescue Exception`                        | Use `rescue StandardError` or specific exceptions.                  |
| Logging full prompts/responses            | Privacy + cost noise. Log IDs and metadata only.                    |
| API keys in source                        | Credentials or ENV — always.                                        |
| Adding gems "we might need"               | Wait until the second consumer appears.                             |

---

## Naming

- Classes: nouns or `VerbSubject` for POROs (`Chat::Replier`,
  `Chat::ReplyJob`).
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
bin/dev                              # web + jobs (foreman)
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
- [ ] Business logic in POROs / jobs, not controllers or channels?
- [ ] Validations on the model — not in POROs / controllers?
- [ ] LLM called only from a job, through `Llm::Client`?
- [ ] Strings in `pt-BR.yml`, accessed via `t(...)`?
- [ ] Request / channel specs cover happy path + failure?
- [ ] **100% line + branch coverage on new/changed code** (`simplecov`)?
- [ ] No mocks for Active Record? VCR for the LLM provider only?
- [ ] `bin/rubocop` passes with zero offenses?
- [ ] No prompt content / response bodies in logs?

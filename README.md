# Rails Chatbot App

[![codecov](https://codecov.io/gh/luisgsilva950/rails-chatbot-app/branch/main/graph/badge.svg?token=oYajspR0Aw)](https://codecov.io/gh/luisgsilva950/rails-chatbot-app)

A simple, well-built chatbot powered by Ruby on Rails 8.1 and
[`ruby_llm`](https://github.com/crmne/ruby_llm). The user opens a page,
types a message, and watches the assistant's reply stream back token by
token over **HTTP + Server-Sent Events (SSE)**. Conversations are
persisted, so you can come back and pick up where you left off.

One thing, done well.

> All coding agents use [.github/copilot-instructions.md](.github/copilot-instructions.md),
> our single instruction entry point in Copilot format. Shared conventions live in
> [docs/engineering.md](docs/engineering.md); setup and validation are in
> [docs/agent-workflow.md](docs/agent-workflow.md).

---

## Stack

- **Ruby** 3.4.2 / **Rails** 8.1
- **PostgreSQL** 16 (multi-db: primary + cache)
- **Solid Cache**
- **HTTP + SSE** (`ActionController::Live`) for the live token stream —
  no ActionCable, no background jobs
- **Hotwire** (Turbo + Stimulus) via importmap
- **`ruby_llm` 2.1** for the LLM
- **RSpec** + FactoryBot + VCR
- **Kamal 2** + Docker for deploy

The UI is deliberately small: ERB + Stimulus + plain CSS. No React, no
Vite, no Tailwind.

---

## Prerequisites

- Ruby 3.4.2 (`rbenv` / `asdf` / `mise`)
- Docker + Docker Compose
- Bundler

---

Existing installations: read the [RubyLLM 2.1 migration guide](docs/ruby-llm-upgrade.md)
before upgrading the database.

## Local setup

```bash
git clone https://github.com/luisgsilva950/rails-chatbot-app.git
cd rails-chatbot-app

# Export an LLM key (Gemini or OpenAI)
export GEMINI_API_KEY=...

# One command: starts Postgres, installs gems, prepares the DBs,
# and boots the dev server.
bin/start
```

`bin/start` aborts early if neither `GEMINI_API_KEY` nor `OPENAI_API_KEY`
is set, then runs `docker compose up -d --wait db` and hands off to
`bin/setup` (which itself execs `bin/dev`).

The app runs at <http://localhost:3000>.

### Manual steps (if you'd rather not use `bin/start`)

```bash
docker compose up -d db   # 1. Postgres
bin/setup                 # 2. gems + db:prepare (then execs bin/dev)
```

### Running everything inside Docker

```bash
docker compose up --build
```

Dev/test Postgres credentials: user `chatbot`, password `chatbot`.

### Dev Container (VS Code / Cursor)

No local Ruby needed — the container ships 3.4.2. Create a `.env` at the
repo root (gitignored) with your key:

```bash
GEMINI_API_KEY=...
RUBY_LLM_DEFAULT_MODEL=gemini-2.5-flash
```

Then **Dev Containers: Reopen in Container**. `.devcontainer/devcontainer.json`
reuses `docker-compose.yml` — it builds `web` from `Dockerfile.dev` and
starts `db` alongside it, so there's no second image to keep in sync.

On first create it runs `bin/setup --skip-server` (gems + `db:prepare`).
Start the server yourself from the integrated terminal:

```bash
bin/dev
```

The container idles rather than running Puma, so a crashed server leaves
you with a working shell instead of a dead container.

---

## LLM configuration

The provider API key goes in an environment variable or **encrypted
credentials**. Never in source. The app reads `GEMINI_API_KEY` and/or
`OPENAI_API_KEY` from the environment first, falling back to credentials.

```bash
EDITOR="code --wait" bin/rails credentials:edit
```

```yaml
gemini_api_key: ...
openai_api_key: ...
```

---

## Agent evaluations

[`ruby_llm-agent-evaluations` 0.2.0](https://rubygems.org/gems/ruby_llm-agent-evaluations/versions/0.2.0)
records opt-in quality runs in the application PostgreSQL database. Ordinary
chat requests do not run evaluations.

```bash
bundle install
bin/rails db:migrate
bin/rails evaluations:run
```

Use a development or test database; the command refuses production. Real runs
require the normal provider credentials and incur model charges. The candidate
uses `RUBY_LLM_DEFAULT_MODEL`; `EVALUATION_JUDGE_MODEL` optionally selects a
different judge model, defaulting to the candidate model. Both models need
credentials for their providers. Automated specs mock provider HTTP only.

Cases live in `Evaluations::ChatSuite`: daily revenue accuracy and exact tool
arguments, booking clarification without claiming a booking, and credential
disclosure refusal without tool calls. Semantic accuracy and answer relevancy
must each reach 0.9; declared ordered action traces must match exactly.
`Evaluations::ChatAgent` invokes the real `Chat::Replier` in a rollback-only
transaction, preserving existing chats and business records. Its structured
output includes assistant text and tool calls so a choices-only reply remains
visible to the judge. Rollback cannot undo external HTTP side effects; use
non-sensitive local business data and the current read-only tool set.

The command persists evidence before exiting nonzero for unmet thresholds,
provider/judge errors, or regressions against the previous compatible run.
Revenue references use the current database and date; changing those references
changes the suite fingerprint and starts a new baseline. Judge scores may vary
between runs; the regression gate uses zero tolerance. Token/cost telemetry is
not reported by this adapter; aggregate zeros are not measured usage or cost.

Run the development server and visit <http://localhost:3000/evaluations> for
history, case evidence, comparisons, and JSON downloads. The read-only dashboard
is mounted **only in development** because the gem has no authentication. It
stores questions, answers, and tool arguments: do not expose it publicly or
evaluate real secrets. The evaluation command suppresses debug SQL/provider
logging and prints only the run ID and aggregate summary.

---

## Common commands

```bash
bin/start                            # check LLM key, start Postgres, setup, run dev server
bin/setup                            # idempotent dev setup (gems + db + dev server)
bin/dev                              # dev server (Puma)
docker compose up -d                 # Postgres

bundle exec rspec                    # run the test suite
bin/rubocop -A                       # autocorrect Ruby style

bin/rails db:prepare                 # creates DBs + loads schemas
bin/rails db:reset                   # drop + create + migrate + seed
bin/rails console
```

---

## Project layout

```
app/
├── agents/          # Sub-agents (e.g. WeatherAgent) for focused domains
├── controllers/     # Thin, RESTful (MessagesController streams SSE)
├── models/          # Conversation, Message
├── services/
│   └── chat/        # Chat::Replier + Chat::ReplyStream (LLM stream → SSE)
├── tools/           # RubyLLM::Tool subclasses, grouped by domain
└── views/           # ERB + Stimulus controllers under app/javascript/
```

Key rules (full details in [docs/engineering.md](docs/engineering.md)):

- Every LLM call goes through `Chat::Replier` (or a sub-agent like
  `WeatherAgent`), streamed to the client by `Chat::ReplyStream` as
  Server-Sent Events.
- Controllers stay thin: create the message, hand the response stream
  to `Chat::ReplyStream`. No LLM logic inline.
- Validations live on the model. Always.
- User-facing strings are English via `t("...")` in
  `config/locales/en.yml`.

---

## Testing

```bash
bundle exec rspec                    # everything
bundle exec rspec spec/requests      # one layer
```

- 100% line and branch coverage on new code (simplecov).
- Mocks only for the LLM provider (VCR with filtered API keys).
- Real Postgres in tests.

---

## Deploy

Kamal 2 with the production `Dockerfile` at the repo root. Configuration
lives in `config/deploy.yml`.

```bash
bin/kamal setup
bin/kamal deploy
```

---

## License

Private.

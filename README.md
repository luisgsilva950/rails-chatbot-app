# Rails Chatbot App

[![codecov](https://codecov.io/gh/luisgsilva950/rails-chatbot-app/branch/main/graph/badge.svg?token=oYajspR0Aw)](https://codecov.io/gh/luisgsilva950/rails-chatbot-app)

A simple, well-built chatbot powered by Ruby on Rails 8.1 and
[`ruby_llm`](https://github.com/crmne/ruby_llm). The user opens a page,
types a message, and watches the assistant's reply stream back token by
token over **HTTP + Server-Sent Events (SSE)**. Conversations are
persisted, so you can come back and pick up where you left off.

One thing, done well.

> Conventions, philosophy, and engineering rules live in [CLAUDE.md](CLAUDE.md).

---

## Stack

- **Ruby** 3.4.2 / **Rails** 8.1
- **PostgreSQL** 16 (multi-db: primary + cache)
- **Solid Cache**
- **HTTP + SSE** (`ActionController::Live`) for the live token stream —
  no ActionCable, no background jobs
- **Hotwire** (Turbo + Stimulus) via importmap
- **`ruby_llm`** for the LLM
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

Key rules (full details in [CLAUDE.md](CLAUDE.md)):

- Every LLM call goes through `Chat::Replier` (or a sub-agent like
  `WeatherAgent`), streamed to the client by `Chat::ReplyStream` as
  Server-Sent Events.
- Controllers stay thin: create the message, hand the response stream
  to `Chat::ReplyStream`. No LLM logic inline.
- Validations live on the model. Always.
- User-facing strings are pt-BR via `t("...")` in
  `config/locales/pt-BR.yml`.

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

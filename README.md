# Rails Chatbot App

A simple, well-built chatbot powered by Ruby on Rails 8.1 and
[`ruby_llm`](https://github.com/crmne/ruby_llm). The user opens a page,
types a message, and watches the assistant's reply stream back token by
token over **ActionCable**. Conversations are persisted, so you can come
back and pick up where you left off.

One thing, done well.

> Conventions, philosophy, and engineering rules live in [CLAUDE.md](CLAUDE.md).

---

## Stack

- **Ruby** 3.4.2 / **Rails** 8.1
- **PostgreSQL** 16 (multi-db: primary + cache + queue + cable)
- **Solid Queue** / **Solid Cache** / **Solid Cable**
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

# 1. Start Postgres in a container
docker compose up -d db

# 2. Install gems and prepare the databases
bin/setup

# 3. Start the app (web + jobs)
bin/dev
```

The app runs at <http://localhost:3000>.

### Running everything inside Docker

```bash
docker compose up --build
```

Dev/test Postgres credentials: user `chatbot`, password `chatbot`.

---

## LLM configuration

The LLM provider API key goes in **encrypted credentials** or an
environment variable. Never in source.

```bash
EDITOR="code --wait" bin/rails credentials:edit
```

```yaml
llm:
  api_key: sk-...
```

---

## Common commands

```bash
bin/setup                            # idempotent dev setup
bin/dev                              # web + jobs (foreman)
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
├── channels/        # ConversationChannel: per-conversation stream
├── controllers/     # Thin, RESTful
├── jobs/            # Chat::ReplyJob — every LLM call goes here
├── models/          # Conversation, Message
├── services/
│   ├── chat/        # Chat::Replier (orchestrates the stream)
│   └── llm/         # Llm::Client (single ruby_llm wrapper)
└── views/           # ERB + Stimulus controllers under app/javascript/
```

Key rules (full details in [CLAUDE.md](CLAUDE.md)):

- Every LLM call happens inside a job, through `Llm::Client`.
- Channels only `subscribe` and `broadcast`. No business logic.
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
# Rails Chatbot App

Um chatbot simples e bem feito, construído com Ruby on Rails 8.1 e
[`ruby_llm`](https://github.com/crmne/ruby_llm). O usuário abre uma página,
digita uma mensagem e vê a resposta do assistente chegar token a token via
**ActionCable**. Conversas são persistidas — dá para voltar e continuar de
onde parou.

Uma coisa só, bem feita.

> Convenções, filosofia e regras de engenharia: veja [CLAUDE.md](CLAUDE.md).

---

## Stack

- **Ruby** 3.4.2 / **Rails** 8.1
- **PostgreSQL** 16 (multi-db: primary + cache + queue + cable)
- **Solid Queue** / **Solid Cache** / **Solid Cable**
- **Hotwire** (Turbo + Stimulus) via importmap
- **`ruby_llm`** para o LLM
- **RSpec** + FactoryBot + VCR
- **Kamal 2** + Docker para deploy

UI deliberadamente pequena: ERB + Stimulus + CSS plano. Sem React, sem
Vite, sem Tailwind.

---

## Pré-requisitos

- Ruby 3.4.2 (`rbenv` / `asdf` / `mise`)
- Docker + Docker Compose
- Bundler

---

## Setup local

```bash
git clone https://github.com/luisgsilva950/rails-chatbot-app.git
cd rails-chatbot-app

# 1. Sobe o Postgres em container
docker compose up -d db

# 2. Instala gems e prepara os bancos
bin/setup

# 3. Sobe a app (web + jobs)
bin/dev
```

A aplicação fica em <http://localhost:3000>.

### Rodando tudo dentro do Docker

```bash
docker compose up --build
```

Credenciais de dev/test do Postgres: usuário `chatbot`, senha `chatbot`.

---

## Configuração do LLM

A chave da API do provedor LLM vai em **credentials encriptadas** ou em
variável de ambiente. Nunca no código.

```bash
EDITOR="code --wait" bin/rails credentials:edit
```

```yaml
llm:
  api_key: sk-...
```

---

## Comandos comuns

```bash
bin/setup                            # setup idempotente
bin/dev                              # web + jobs (foreman)
docker compose up -d                 # Postgres

bundle exec rspec                    # roda os testes
bin/rubocop -A                       # autocorreção de estilo Ruby

bin/rails db:prepare                 # cria DBs + carrega schemas
bin/rails db:reset                   # drop + create + migrate + seed
bin/rails console
```

---

## Estrutura

```
app/
├── channels/        # ConversationChannel: stream por conversa
├── controllers/     # RESTful, finos
├── jobs/            # Chat::ReplyJob — toda chamada ao LLM passa aqui
├── models/          # Conversation, Message
├── services/
│   ├── chat/        # Chat::Replier (orquestra o stream)
│   └── llm/         # Llm::Client (wrapper único do ruby_llm)
└── views/           # ERB + Stimulus controllers em app/javascript/
```

Regras-chave (detalhes em [CLAUDE.md](CLAUDE.md)):

- Toda chamada ao LLM acontece dentro de um job, via `Llm::Client`.
- Channels só fazem `subscribed`/`broadcast`. Nenhuma lógica de negócio.
- Validações ficam no model. Sempre.
- Strings de UI em `pt-BR` via `t("...")` em `config/locales/pt-BR.yml`.

---

## Testes

```bash
bundle exec rspec                    # tudo
bundle exec rspec spec/requests      # uma camada
```

- 100% de cobertura de linha e branch em código novo (simplecov).
- Mocks só para o provedor LLM (VCR com filtro de chaves).
- Postgres real nos testes.

---

## Deploy

Kamal 2 com o `Dockerfile` de produção na raiz. Configuração em
`config/deploy.yml`.

```bash
bin/kamal setup
bin/kamal deploy
```

---

## Licença

Privado.
# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...

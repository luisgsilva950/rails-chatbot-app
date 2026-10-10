# RubyLLM 2.1 upgrade

The app pins RubyLLM `~> 2.1.0`. Application-owned `Chat` and `Message`
records remain in place; RubyLLM owns the model registry, tool calls, usage
ledger and supporting tables under `ruby_llm_*` names.

## Existing databases

Back up the primary database and stop application processes, including active
SSE requests, before migrating. This uses upstream's **rename** strategy;
old and new application versions must not write concurrently.

```bash
BUNDLE_FROZEN=true bundle install
bin/rails db:migrate
bin/rails ruby_llm:load_models
bin/rails zeitwerk:check
```

Run these commands with the deployed environment and database configuration
(e.g. `RAILS_ENV=production`). The model-loading task uses the packaged
registry and requires no provider network call. Restart the application only
after all commands succeed. Check a saved conversation and a streamed reply.
For Docker development, prefix each command with `docker compose run --rm web`.

The schema already had RubyLLM 1.16's required message/tool-call columns.
The checked-in migrations apply the 2.0 prepare, backfill and finish phases
before the 2.1 additions. They preserve chat/message/model/tool-call IDs,
structured content, thinking signatures, tool-result links and all five token
counters. Usage rows record the original provider/model and timestamps.

The 2.0 migrations were rendered from the upstream PostgreSQL rename-mode
templates, retaining validation, concurrent indexes and resumable backfills.
Their small content-rendering helper is frozen under `db/migrate/support/`,
with upstream's MIT license, because RubyLLM 2.1 removes its 2.0 helpers.
Do not replace these historical migrations with calls to the installed gem's
upgrade generator. This allows both existing databases and fresh installs to
migrate while using the final 2.1 dependency.

Legacy message columns and the backfill progress table remain for inspection;
cleanup can follow in a separate deployment after all environments are
verified. The migrations fail explicitly when legacy usage lacks an
identifiable model. Repair the affected model references before retrying;
do not invent provider/model identities or reset the database.

These migrations are forward-only. Rollback requires restoring the backup
and the previous application version together, rather than `db:rollback`.

## Behavior changes

Tools use `parameters`, and provider timing hooks the 2.1 transport connection.
RubyLLM removed `Tool#halt`, so `Chat::Replier` controls the `step` loop. Valid
choices execute and persist their result, then pause without another model
request. Invalid choices return an error the model can recover from. Ordinary
tools continue to a model answer; tools needing approval pause safely. The
SSE `chunk` / `tool` / `done` and named `ui` event contracts remain the same.

The migration specs rehearse the complete historical migration chain in an
isolated PostgreSQL schema. Request/service specs mock only provider HTTP
responses and verify streaming, persistence, usage and choices resumption.

Upstream references: [2.0 guide](https://github.com/crmne/ruby_llm/blob/v2.0.0/docs/_reference/upgrading.md)
and [2.1 guide](https://rubyllm.com/upgrading/).

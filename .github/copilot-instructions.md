# Repository instructions for coding agents

These instructions apply to the whole repository, regardless of the agent,
editor, or model. Read [docs/engineering.md](../docs/engineering.md) before
implementation and [docs/agent-workflow.md](../docs/agent-workflow.md) for setup
and validation. This is the single repository instruction entry point, using
the Copilot Markdown format for any coding agent. Keep project guidance here
and in the linked documents; do not add vendor-specific adapters.

## Project map

Rails 8.1 / Ruby 3.4.2 chatbot backed by PostgreSQL 16 and `ruby_llm`.
The UI uses ERB, importmap, Turbo, Stimulus, and plain CSS. Replies stream
over HTTP Server-Sent Events (SSE); there are no background jobs or Redis.

- `app/controllers/`: request handling; keep controllers thin.
- `app/models/`: persisted chats, messages, and business data; validations here.
- `app/services/chat/`: request-facing reply entry point and SSE transport.
- `app/agents/`: main chat, inventory, weather, and evaluation judge agents.
- `app/tools/`: scheduling, cash-flow, customer, inventory, weather, and UI tools.
- `app/javascript/controllers/chat_controller.js`: streaming UI client.
- `config/locales/en.yml`: user-facing strings.
- `spec/`: RSpec request, service, agent, and tool tests.
- `docs/adr/`: decisions; read relevant ADRs before changing their contracts.

## Working agreement

1. Inspect the requested behavior, relevant code, tests, and `git status`
   before editing. Preserve existing user changes and use the current checkout
   in isolated cloud tasks; do not create a worktree unless requested.
2. For nontrivial work, state a short plan and choose the smallest change that
   solves the problem. Follow existing Rails conventions and avoid speculative
   abstractions, dependencies, or unrelated cleanup.
3. Add a regression test for a bug and test behavior for a feature. Keep
   application logic out of setup scripts and instruction files.
4. Run relevant checks, inspect the diff, and report what changed, what ran,
   and any failures or unverified behavior. Never call skipped checks passing.

## Contracts to preserve

- Main chat calls go through `Chat::Replier` and `Chat::ReplyStream`; `ChatAgent`
  owns the main prompt, tools, and reply loop on the persisted conversation.
  Domain agents own their focused provider calls. Never put LLM logic in controllers.
- SSE events and the Stimulus client form a shared contract. Changes must
  cover both sides, stream completion, and closure on errors. See
  [the choices ADR](../docs/adr/0001-model-suggested-choices-over-sse.md).
- Use model validations and database constraints for data integrity. Mock
  external LLM boundaries in tests, never Active Record; use real PostgreSQL.
- Use English identifiers and localized UI strings via `t(...)`. Preserve
  names returned from stored business data.
- Keep API keys in environment variables or encrypted credentials. Never
  print or commit keys, credential files, or prompt/response content in logs.

## Validation

Use RSpec, not `bin/rails test`. `.github/workflows/ci.yml` is the CI reference;
`bin/ci` currently includes generated Minitest commands and is not an RSpec
validation shortcut.

```bash
RAILS_ENV=test bin/rails db:prepare
bundle exec rspec
bin/rubocop
bin/rails zeitwerk:check
```

RSpec enforces 100% line and branch coverage. Provider calls are mocked, so
tests do not require a real API key. Protect the tracked `coverage/` reports
from incidental changes; see the workflow document. For documentation-only
changes, validate links, referenced commands, and consistency without adding
tests that simply duplicate text.

For runtime, schema, or dependency changes, also validate the affected startup,
migrations, or CI security checks listed in the workflow document. Do not reset
a database or apply unsafe lint corrections as a routine validation step.

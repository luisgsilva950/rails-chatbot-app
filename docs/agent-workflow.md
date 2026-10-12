# Coding-agent workflow

Start with [repository instructions](../.github/copilot-instructions.md) and
[engineering conventions](engineering.md). These documents describe work on
the repository; the chatbot's runtime prompts remain in `app/services/chat/`
and `app/agents/`.

## Single instruction entry point

`.github/copilot-instructions.md` is the repository's generic coding-agent
harness. It uses the Copilot Markdown instruction format, with ordinary project
rules that apply to any agent, editor, or model. Detailed conventions and setup
commands live in the linked documents.

Use this same file with every agent. Tools that support this format can load
it directly; otherwise explicitly include it in the session context and ask
the agent to read the linked documents. Do not assume a Markdown link loads
another file automatically. There are no vendor-specific wrappers or separate
copies of the instructions. Update this file and the shared documents when
commands or architecture change.

## Inspect before editing

- Check `git status --short` and preserve existing work.
- Read the relevant implementation, specs, and ADRs. Use the checked-in
  `.ruby-version`, `Gemfile.lock`, and database configuration.
- Decide what demonstrates the requested behavior. Keep live provider checks
  separate from automated tests so missing credentials do not block unit and
  request tests.

## Native Ruby setup

Requirements: Ruby **3.4.2**, Bundler **4.0.8**, PostgreSQL **16**, and the
native libraries listed in `Dockerfile.dev` (including libpq, libyaml, and
libvips). Run from the repository root:

```bash
docker compose up -d --wait db
BUNDLE_FROZEN=true bundle install
bin/setup --skip-server
RAILS_ENV=test bin/rails db:prepare
```

`bin/setup --skip-server` prepares the development database and clears local
logs/tempfiles. Omit `--skip-server` only when you want it to launch Rails.
Do not pass `--reset` unless resetting the development data is intended.
Dependency updates should be explicit; do not silently regenerate a lockfile
to work around an installation failure.

## Docker setup

Use this when Ruby is unavailable on the host:

```bash
docker compose build web
docker compose up -d --wait db
docker compose run --rm web bin/setup --skip-server
docker compose run --rm -e RAILS_ENV=test web bin/rails db:prepare
docker compose up -d web
```

The checkout is mounted at `/rails` in `web`. Run commands through
`docker compose exec -T web ...` for a running service or
`docker compose run --rm web ...` for a one-off command. Rebuild the image
when its system dependencies change. The Compose bundle cache can need a
`bundle install` when the lockfile changes.

Managed environments may supply tested installation/startup instructions
instead. Use those instructions and the existing checkout. If containers need
a proxy or custom CA, forward the platform's supported proxy settings and
trusted CA certificates; preserve TLS, package signatures, and gem checksums.
Do not hardcode machine addresses or secrets into repository configuration.

## Run the app

For native Ruby, run `bin/dev`. For Docker, use `docker compose up -d web`.
Check the rendered homepage and the affected user flow, not only a listening
port. Inspect server logs for startup errors.

Live chat creation and provider replies require `GEMINI_API_KEY` or
`OPENAI_API_KEY` in the environment or encrypted Rails credentials.
`RUBY_LLM_DEFAULT_MODEL` defaults to `gemini-3-flash-preview`; when using OpenAI,
select a model for that provider. `bin/start` checks for an environment key
before starting Postgres and Rails. A homepage without a key does not prove
that chat creation or streamed replies work. Supply secrets through the
environment's secure configuration, never chat, commits, or instruction files.

## Verify a change

With native Ruby, run from the repository root:

```bash
RAILS_ENV=test bin/rails db:prepare
bundle exec rspec
bin/rubocop
bin/rails zeitwerk:check
```

For Docker, prefix those commands with `docker compose run --rm web`, placing
`-e RAILS_ENV=test` before `web` for database preparation. Real API keys are
unnecessary: `spec/rails_helper.rb` supplies test-only keys and WebMock blocks
external HTTP. Do not use those test keys for a live provider check. If proxy
environment discovery causes DNS delays in mocked tests, clear proxy variables
only for the test process, keeping the application's network configuration.

Start with relevant specs while developing, then run the full suite for Ruby
behavior changes so SimpleCov can enforce its 100% line/branch coverage gate.
RSpec reports must include the example count and failures; a zero-example run
is not validation. Documentation-only changes need link and command checks.

`coverage/` contains tracked generated reports. Avoid including incidental
report changes in a PR. In Docker, redirect output with an external bind mount:

```bash
mkdir -p /tmp/rails-chatbot-coverage
docker compose run --rm \
  -v /tmp/rails-chatbot-coverage:/rails/coverage \
  web bundle exec rspec
```

If a native run updates tracked reports, preserve any pre-existing changes and
restore only artifacts generated by your run. Inspect `git diff` before doing
so.

The GitHub CI workflow also runs these checks:

```bash
bin/brakeman --no-pager
bin/bundler-audit
bin/importmap audit
```

Run the relevant security checks for dependency or security changes. Audits
can need network access; report an access failure separately from a detected
vulnerability. Use `.github/workflows/ci.yml` as the CI reference. `bin/ci`
still contains generated `bin/rails test` commands; it does not run the RSpec
suite and includes destructive test reseeding.

## Prepare the PR

Inspect `git diff --check`, the final diff, and `git status --short`. Keep
credentials, unrelated edits, generated reports, and local setup files out of
the commit. Explain the concrete problem, resulting behavior, and validation
results. Include remaining failures or unverified behavior, and use the
engineering checklist where it applies. Keep changes reviewable and do not
merge or deploy as part of opening a PR.

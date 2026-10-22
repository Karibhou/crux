# Crux

The agent runtime inside [Hive](https://github.com/hivecommons/hive), split out as a reusable component.

Crux runs AI coding agents from definitions: short-lived agents with a clean context, external context injected each run, limits enforced in code at the tool boundary, a gate before anything lands, and an audit log a human owns. Hive is its first consumer; anything that needs a governed agent can be the next.

## Status

Placeholder. The code is being carved out of the hive repo in stages, tracked in [hivecommons/hive#13536](https://github.com/hivecommons/hive/issues/13536):

1. In-repo boundary inside hive (`crux.Runtime` interface, architecture ratchet, tmux funnel, agent config struct, CI path filters).
2. Nested Go module in hive with its own tags and a `crux` binary (`run`, `ps`, `logs`, `kick`, `stop`).
3. `crux serve` with an API, auth and quotas; the code moves here and Hive becomes a client. Multi-tenancy when there is a second tenant.

Design note: `src/docs/design/crux.md` in the hive repo once stage 1 lands.

## What is in scope

- Run an agent from a definition: engine, model, prompt, tools, limits.
- Lifecycle: start, observe, nudge, stall and crash-loop recovery, stop.
- Engines: Claude, Copilot, Gemini, Goose, Codex, Aider, Bob; any OpenAI-compatible model through the gateway.
- Policy enforcement at the tool boundary (MITM proxy, tool approval).
- Isolation: container sandbox, Kubernetes job.
- Telemetry and audit via [pluk](https://github.com/hivecommons/pluk).

Out of scope, and staying in Hive: governor, GitHub and forge integration, review, evidence, dashboard, hub.

## Name

Crux: the point everything turns on. Unrelated projects share the word (redbadger/crux, Google CrUX, CRUX Linux); none in this field.

## License

Apache-2.0.

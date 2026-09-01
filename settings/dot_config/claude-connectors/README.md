# claude-connectors

Use your **claude.ai MCP connectors** (Slack, Google Drive, Gmail, Calendar,
Glean, ...) from any local MCP client — pi, Cursor, MCP Inspector — **without
running Claude Code as a subprocess**.

```
$ claude-connectors status
account token : expires in 427 min
scopes        : user:file_upload, user:inference, user:mcp_servers, ...

  slack        ok    18 tools
  drive        ok     8 tools
  gmail        ok    16 tools
  calendar     ok     9 tools
```

---

## Why this exists

claude.ai connectors are **not** local MCP servers. Their OAuth tokens live
server-side at Anthropic, tied to your claude.ai account — they are not in your
keychain, and the providers (Slack, Google) don't support dynamic client
registration, so a third-party client can't mint its own.

The workaround: Anthropic runs a **gateway** that holds those tokens and proxies
MCP traffic over them.

```
https://mcp-proxy.anthropic.com/v1/mcp/{installedServerId}
```

Your Claude Code account token — in the macOS keychain, carrying the
`user:mcp_servers` scope — is accepted by that gateway. So any client holding
that token can reach every connector you've authorized, natively.

This directory packages that up.

---

## Layout

```
~/.config/claude-connectors/
├── README.md                   <- you are here
├── connectors.json             <- GENERATED: alias -> server id (edit via `sync`)
├── bin/
│   ├── connectors.ts           <- management CLI (sync/status/tools/call/doctor)
│   └── connector-mcp.ts        <- stdio<->HTTP MCP shim used by pi
└── lib/
    └── common.ts               <- token refresh, keychain, HTTP, registry
```

This is a Bun/TypeScript toolkit; the entrypoints have a `#!/usr/bin/env bun`
shebang and are executable. It replaced the earlier Python implementation. The
source is managed by chezmoi under `settings/dot_config/claude-connectors/`.

`~/.local/bin/claude-connectors` and `~/.local/bin/claude-connector-mcp` are
symlinks onto these `.ts` entrypoints, so the short command names stay on
`PATH` and now run Bun. chezmoi recreates those symlinks on a fresh machine
from `settings/dot_local/bin/symlink_*.tmpl`.

---

## Setup from scratch

```bash
claude-connectors sync      # discover connectors, write connectors.json
claude-connectors status    # verify each one handshakes
```

`sync` only records connectors marked **connected**. To add a new one:

```bash
claude mcp login "claude.ai Notion"   # authorize once, in Claude Code
claude-connectors sync                # pick up its server id
```

Then register it with pi (see below).

---

## Wiring into pi

`~/.pi/agent/mcp.json` runs the shim as a stdio server, one entry per connector:

```json
{
  "mcpServers": {
    "slack":  { "command": "bun", "args": ["/Users/tatlas/.config/claude-connectors/bin/connector-mcp.ts", "slack"],    "lifecycle": "lazy" },
    "gdrive": { "command": "bun", "args": ["/Users/tatlas/.config/claude-connectors/bin/connector-mcp.ts", "drive"],    "lifecycle": "lazy" },
    "gmail":  { "command": "bun", "args": ["/Users/tatlas/.config/claude-connectors/bin/connector-mcp.ts", "gmail"],    "lifecycle": "lazy" },
    "gcal":   { "command": "bun", "args": ["/Users/tatlas/.config/claude-connectors/bin/connector-mcp.ts", "calendar"], "lifecycle": "lazy" }
  }
}
```

(The absolute `bun …/connector-mcp.ts` form is used so pi doesn't depend on
`PATH`; the `claude-connector-mcp` symlink is the equivalent PATH shortcut.)

`lifecycle: lazy` means nothing connects until a tool is actually called.

Tools are namespaced by the pi server key, so the Slack tool `slack_search_public`
becomes **`slack_slack_search_public`**, and Drive's `list_recent_files` becomes
**`gdrive_list_recent_files`**. Discover them with `mcp({search: "..."})`.

To add a connector: `claude-connectors sync`, add a block above, restart pi.

---

## CLI reference

| Command | Purpose |
|---|---|
| `claude-connectors sync [-v]` | Rebuild `connectors.json`. `-v` also lists unauthenticated connectors. |
| `claude-connectors list` | Show registry: alias, name, server id. |
| `claude-connectors status` | Token expiry + live handshake per connector. **Start here when something breaks.** |
| `claude-connectors tools <alias> [-v]` | List a connector's tools; `-v` adds descriptions. |
| `claude-connectors call <alias> <tool> --args '{...}'` | Invoke a tool directly. Best way to test outside pi. |
| `claude-connectors token` | Print a valid account token (auto-refreshes). |
| `claude-connectors doctor` | Check curl, keychain, token, registry, gateway. |

```bash
claude-connectors tools slack -v
claude-connectors call drive list_recent_files --args '{"page_size": 3}'
claude-connectors call slack slack_search_public --args '{"query": "deploy", "limit": 5}'
```

### File-path arguments

So you don't have to inline (and shell-escape) an entire file into an argument,
any tool taking `textContent` / `base64Content` (e.g. Drive `create_file`)
accepts a virtual `*File` sibling key pointing at a path. The shim and the
`call` command read it and substitute the real argument before the request is
sent. `~` and relative paths are resolved; `contentMimeType` is inferred from
the extension (`.md`→`text/markdown`, `.pdf`→`application/pdf`, …) when you
don't set one:

```bash
claude-connectors call drive create_file \
  --args '{"title": "Notes", "textContentFile": "~/notes.md"}'
```

Use `base64ContentFile` for binary uploads. Passing both a `*File` key and its
inline counterpart, or an unreadable path, is a clear error.

The shim also advertises these keys: it augments `tools/list` responses so any
tool exposing `textContent`/`base64Content` gains the matching `*File` property
(never marked `required`) in its `inputSchema`, so pi and the model discover
the convention without being told.

---

## How it works

**Token handling** (`lib/common.ts`). Reads the keychain item
`Claude Code-credentials` — the same one Claude Code uses. If the access token
is within 5 minutes of expiry it refreshes via the Claude Code public OAuth
client and **writes the result back**, so Claude Code and pi stay in sync.
Access tokens last ~12h; the refresh token ~3 weeks.

**The shim** (`bin/connector-mcp.ts`) reads JSON-RPC on stdin, POSTs each
message to the gateway, parses the SSE response, writes JSON-RPC to stdout.
It's deliberately thin — no protocol logic, so it stays correct as MCP evolves.

Two non-obvious details, both discovered by trial and error:

1. **`X-Mcp-Client-Session-Id` is mandatory.** Undocumented; the gateway
   returns `400 Field required` without it. One UUID per process.
2. **All HTTPS goes through `curl`, not `fetch`.** This machine sits behind
   TLS interception. Bundled CA stores (Bun's native `fetch`) reject the
   intercepting cert (`CERTIFICATE_VERIFY_FAILED: Basic Constraints of CA cert
   not marked critical`); `curl` trusts the system keychain and works. **Don't
   "modernize" this to `fetch` — it will break.**

The token is fetched per request, so long-running pi sessions survive token
expiry without a restart.

---

## Troubleshooting

Run `claude-connectors doctor` first, then `status`.

**A connector reports FAIL, or its tools vanished.**
Its upstream OAuth grant likely expired. Re-authorize and re-sync:
```bash
claude mcp login "claude.ai Google Drive"
claude-connectors sync
```

**`claude mcp list` says Connected but tools are missing.**
That health check is unreliable — it reported Drive as `✔ Connected` while the
token was dead. Trust `claude-connectors status`, which does a real handshake.

**`unknown connector 'x'`.** Registry is stale: `claude-connectors sync`.

**`CERTIFICATE_VERIFY_FAILED`.** Something bypassed the curl transport. See
note 2 above.

**`could not read keychain item` / `run: claude /login`.** Log in to Claude
Code once; everything here piggybacks on that session.

**Everything fails at once.** Likely an upstream change — this is an
unofficial interface (see below). Fall back to `cmcp` (next section) and
re-derive the gateway contract by searching the Claude Code binary:
```bash
strings "$(readlink -f "$(which claude)")" | grep -E 'mcp-proxy|/v1/mcp'
```

---

## Fallback: the `cmcp` bridge

`~/.local/bin/cmcp` predates this and drives connectors by shelling out to
`claude -p` with tools scoped to one connector:

```bash
cmcp slack "find messages mentioning deploy this week"
```

Slower, and answers pass through a summarizing model rather than returning raw
JSON — but it rides **supported** Claude Code paths. If the gateway contract
changes, `cmcp` should keep working. Kept deliberately.

---

## Stability caveat

`mcp-proxy.anthropic.com` is **not a documented public API**. It was found by
inspecting the Claude Code binary. Anthropic may change the URL shape, headers,
or auth at any time. Nothing here is load-bearing for anyone but you — if it
breaks, `doctor` plus the fallback above are the recovery path.

Server ids are no longer hardcoded; `sync` re-derives them from
`/api/oauth/organizations/{org}/mcp/connectors/list`.

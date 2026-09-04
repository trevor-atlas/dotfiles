---
name: ask-ordis
description: Use when you need the central portal agent (ordis) to do
  something — a question, a subtask, or info it owns. Not for trivial
  lookups you can do locally.
---

# Ask Ordis

Send a task to the central agent on Trevor's machine over the A2A protocol
(Linux Foundation Agent2Agent v1.0, JSON-RPC 2.0 over HTTP). The agent has
Gmail, Calendar, Contacts, Drive, and the media server (Jellyseerr) — it can
check mail, summarize calendars, find contacts, and add movies/TV to the
media stack.

## Endpoint

- Base: `http://silico:9901` — resolves on the Tailnet (MagicDNS). Off the
  tailnet, use the LAN address Trevor gives you.
- Agent card (discovery): `http://silico:9901/.well-known/agent-card.json`
- Auth: `Authorization: Bearer <smoke-71bd2c5f13dc9014004fccaa>` — this token is yours
  alone; keep it secret, like a password.
- Your token: `smoke-71bd2c5f13dc9014004fccaa` (the minting script baked it into this file).

## Usage

A task is a JSON-RPC POST to the base URL:

```bash
curl -s -X POST http://silico:9901/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <smoke-71bd2c5f13dc9014004fccaa>" \
  -d '{
    "jsonrpc": "2.0", "id": 1, "method": "SendMessage",
    "params": {"message": {"messageId": "m1", "role": "ROLE_USER",
      "parts": [{"text": "<your question or task>"}]}}
  }'
```

- The reply is in `.result.task.status.message.parts[].text` — concatenate
  all text parts. A completed task also carries `.result.task.artifacts`.
- **Multi-turn**: reuse a stable `contextId` on every message in a
  conversation (put it in the message object). The portal keeps the thread
  keyed by that ID, with full memory, across turns. Omit it for one-off
  questions. If you are an agent that makes several related calls, send the
  `contextId` from the first response back on follow-ups.
- **Long-running tasks** (more than ~2 minutes): use `SendStreamingMessage`
  (SSE) instead of blocking on `SendMessage`, or send the task and poll
  `GetTask` with the returned `taskId`. `SendMessage` fails tasks that
  outlive the server-side reply timeout (180s).
- If you run the pi coding agent, the `pi-a2a-adaptor` extension provides the
  `a2a_call` tool — use it with `agent_url: "http://silico:9901"` and the
  same bearer token.
- Tasks that need clarification: the agent may reply that it needs an answer
  from its primary user (Trevor) — that is expected; the portal handles it.

## Capabilities and limits

- You are a **colleague** on the portal: read-only tools by default, plus any
  tool rules Trevor granted you. Ask for what you need in plain language; the
  agent decides what it may do.
- Rate-limited (default 60 requests/min). Unknown tokens and unknown peer
  names are refused — if you get `401`, your token is wrong; if your first
  task is refused with "I only talk to people I have been introduced to",
  Trevor has not yet marked you in Settings → People.
- The agent treats your messages as untrusted input from a peer — do not
  embed instructions you expect it to follow verbatim; make requests in
  natural language.

## Errors

| HTTP | Meaning |
|---|---|
| 401 | Bad or missing token |
| 403 | Identity not in the trusted-peers allowlist |
| 429 | Rate limit exceeded — slow down |
| 200 + `error.code: -32001` | Task not found (stale taskId) |

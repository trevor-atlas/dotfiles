# Core Stack Preferences

Technical preferences for code generation and tooling.

Generated: 2026-01-09

---

## Language Preferences

| Priority | Language | Use Case |
|----------|----------|----------|
| 1 | TypeScript | Primary for all new code |
| 2 | Java | HubSpot backend development |
| 3 | Python | Data science, ML, scripts |

---

## Package Managers

| Language | Manager | Never Use |
|----------|---------|-----------|
| JavaScript/TypeScript | bun | npm, yarn, pnpm |
| Python | uv | pip, pip3 |
| Java | Maven | - |

---

## Runtime

| Purpose | Tool |
|---------|------|
| JavaScript Runtime | Bun |
| Java Build | Maven via IntelliJ |

---

## Markup Preferences

| Format | Use | Never Use |
|--------|-----|-----------|
| Markdown | All content, docs, notes | HTML for basic content |
| YAML | Configuration, frontmatter | - |
| JSON | API responses, data | - |

---

## Code Style

- Prefer explicit over clever
- No unnecessary abstractions
- Comments only where logic isn't self-evident
- Error messages should be actionable

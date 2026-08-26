#!/usr/bin/env node
/**
 * measure-context.ts — pi startup context attribution.
 *
 * Loads the same config pi loads (global settings from ~/.pi/agent), then
 * measures each registered tool/command/flag/shortcut and each skill:
 *
 *   STARTUP cost  = tool schemas + commands/flags/shortcuts + skill listings
 *                   (name + description) — paid in every system prompt/request.
 *   ON-INVOKE cost = full SKILL.md bodies — paid only when the model reads a
 *                   skill file during a task.
 *
 * Token estimate: chars/4 (same heuristic pi uses in estimateTokens).
 *
 * Usage:  node ~/.pi/agent/scripts/measure-context.ts
 */
import { readFileSync, existsSync, realpathSync, mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { execSync } from "node:child_process";
import { pathToFileURL } from "node:url";

// ---- resolve the pi package regardless of where this script is run from ----
function findPiPackage(): string | undefined {
  const candidates: string[] = [];
  if (process.env.PI_PACKAGE_DIR) candidates.push(process.env.PI_PACKAGE_DIR);
  try {
    const bin = execSync("command -v pi || which pi", { encoding: "utf8" }).trim().split("\n")[0];
    if (bin) {
      try {
        const real = realpathSync(bin);
        const marker = "@earendil-works/pi-coding-agent";
        const idx = real.indexOf(marker);
        if (idx >= 0) candidates.push(real.slice(0, idx + marker.length));
      } catch {}
      candidates.push(join(dirname(bin), "..", "lib", "node_modules", "@earendil-works", "pi-coding-agent"));
    }
  } catch {}
  try {
    const root = execSync("npm root -g", { encoding: "utf8" }).trim();
    candidates.push(join(root, "@earendil-works", "pi-coding-agent"));
  } catch {}
  candidates.push("/opt/homebrew/lib/node_modules/@earendil-works/pi-coding-agent");
  candidates.push("/usr/local/lib/node_modules/@earendil-works/pi-coding-agent");
  for (const c of candidates) {
    try {
      if (existsSync(join(c, "dist", "index.js"))) return c;
    } catch {}
  }
  return undefined;
}

const piPkg = findPiPackage();
if (!piPkg) {
  console.error("Could not locate the @earendil-works/pi-coding-agent package (set PI_PACKAGE_DIR to point at it).");
  process.exit(1);
}
const pi = await import(pathToFileURL(join(piPkg, "dist", "index.js")).href);
const { DefaultResourceLoader, SettingsManager, getAgentDir } = pi;

const agentDir = getAgentDir();
const cwd = mkdtempSync(join(tmpdir(), "pi-ctx-measure-")); // clean scratch: no .pi, no git

const settingsManager = SettingsManager.create(cwd, agentDir);
const loader = new DefaultResourceLoader({ cwd, agentDir, settingsManager });
await loader.reload();

const { extensions, errors } = loader.getExtensions();
const { skills } = loader.getSkills();

const tokens = (s: string | number) => Math.ceil(Number(s) / 4);
const ser = (obj: unknown) => {
  try {
    return JSON.stringify(obj);
  } catch {
    return String(obj);
  }
};

interface Group {
  label: string;
  tools: { name: string; chars: number }[];
  commands: { name: string; chars: number }[];
  flags: { name: string; chars: number }[];
  shortcuts: { name: string; chars: number }[];
  skillsListed: { name: string; chars: number }[];
  skillsBodies: { name: string; chars: number; filePath: string }[];
  handlers: number;
  totalChars: number;
}

const groups = new Map<string, Group>();

function groupFor(label: string): Group {
  let g = groups.get(label);
  if (!g) {
    g = { label, tools: [], commands: [], flags: [], shortcuts: [], skillsListed: [], skillsBodies: [], handlers: 0, totalChars: 0 };
    groups.set(label, g);
  }
  return g;
}

for (const ext of extensions) {
  const source = ext.sourceInfo?.source ?? "unknown";
  const label = `${source}${ext.sourceInfo?.scope ? ` (${ext.sourceInfo.scope})` : ""}`;
  const g = groupFor(label);

  for (const [name, rt] of ext.tools) {
    const d = rt.definition;
    const parts: Record<string, unknown> = { name: d.name ?? name, label: d.label };
    if (d.description) parts.description = d.description;
    if (d.promptSnippet) parts.promptSnippet = d.promptSnippet;
    if (d.promptGuidelines) parts.promptGuidelines = d.promptGuidelines;
    if (d.parameters) parts.parameters = d.parameters;
    const chars = ser(parts).length;
    g.tools.push({ name: d.name ?? name, chars });
    g.totalChars += chars;
  }
  for (const [name, cmd] of ext.commands) {
    const chars = ser({ name, description: (cmd as any).description }).length;
    g.commands.push({ name, chars });
    g.totalChars += chars;
  }
  for (const [name, flag] of ext.flags) {
    const chars = ser({ name, description: (flag as any).description }).length;
    g.flags.push({ name, chars });
    g.totalChars += chars;
  }
  for (const [name, sh] of ext.shortcuts) {
    const chars = ser({ shortcut: (sh as any).shortcut ?? name }).length;
    g.shortcuts.push({ name, chars });
    g.totalChars += chars;
  }
  g.handlers += ext.handlers.size;
}

for (const skill of skills) {
  const source = skill.sourceInfo?.source ?? "unknown";
  const label = `${source}${skill.sourceInfo?.scope ? ` (${skill.sourceInfo.scope})` : ""}`;
  const g = groupFor(label);
  const listed = ser({ name: skill.name, description: skill.description }).length;
  g.skillsListed.push({ name: skill.name, chars: listed });
  g.totalChars += listed;

  let bodyChars = 0;
  let filePath = skill.filePath;
  try {
    if (existsSync(filePath)) {
      bodyChars = readFileSync(filePath, "utf-8").length;
    }
  } catch {}
  g.skillsBodies.push({ name: skill.name, chars: bodyChars, filePath });
  g.totalChars += bodyChars;
}

// context files (AGENTS.md etc.) — baseline cost, not extension-owned
let agentsChars = 0;
try {
  const { agentsFiles } = loader.getAgentsFiles();
  for (const f of agentsFiles) agentsChars += f.content.length;
} catch {}

// ---- report ----
// STARTUP = what's in every system prompt: tools + commands/flags/shortcuts + skill LISTINGS.
// ON-INVOKE = skill bodies (full SKILL.md), paid only when the model reads the skill file during a task.
const rows: { label: string; tools: number; skLst: number; other: number; total: number; handlers: number }[] = [];
for (const g of groups.values()) {
  const toolsChars = g.tools.reduce((a, t) => a + t.chars, 0);
  const listedChars = g.skillsListed.reduce((a, t) => a + t.chars, 0);
  const other = g.totalChars - toolsChars - listedChars - g.skillsBodies.reduce((a, t) => a + t.chars, 0);
  rows.push({ label: g.label, tools: tokens(toolsChars), skLst: tokens(listedChars), other: tokens(other), total: tokens(toolsChars + listedChars + other), handlers: g.handlers });
}
rows.sort((a, b) => b.total - a.total);

let startupTools = 0;
let startupListed = 0;
let startupOther = 0;
let onInvokeTotal = 0;
for (const g of groups.values()) {
  const toolsChars = g.tools.reduce((a, t) => a + t.chars, 0);
  const cmdChars = g.commands.reduce((a, t) => a + t.chars, 0) + g.flags.reduce((a, t) => a + t.chars, 0) + g.shortcuts.reduce((a, t) => a + t.chars, 0);
  const listed = g.skillsListed.reduce((a, t) => a + t.chars, 0);
  const bodies = g.skillsBodies.reduce((a, t) => a + t.chars, 0);
  startupTools += toolsChars;
  startupListed += listed;
  startupOther += cmdChars;
  onInvokeTotal += bodies;
}

// flat per-skill list for dedicated reporting
const allSkills = [];
for (const g of groups.values()) {
  const listedBy = new Map(g.skillsListed.map((s) => [s.name, s.chars]));
  for (const s of g.skillsBodies) {
    allSkills.push({ name: s.name, source: g.label, listed: listedBy.get(s.name) ?? 0, body: s.chars, filePath: s.filePath });
  }
}
allSkills.sort((a, b) => b.body - a.body);

console.log("=== STARTUP cost per group (in every system prompt, every request) ===");
console.log("group".padEnd(46), "tools".padStart(7), "skLst".padStart(7), "other".padStart(7), "total".padStart(7), "handlers");
for (const r of rows) {
  console.log(r.label.padEnd(46), String(r.tools).padStart(7), String(r.skLst).padStart(7), String(r.other).padStart(7), String(r.total).padStart(7), String(r.handlers).padStart(8));
}
console.log("");
console.log(`STARTUP TOTAL: ~${tokens(startupTools + startupListed + startupOther)} tokens  (tools ~${tokens(startupTools)} + skill listings ~${tokens(startupListed)} + commands/flags/shortcuts ~${tokens(startupOther)})`);
console.log("context files (AGENTS.md etc., loaded at startup):", tokens(agentsChars), "tokens");
console.log("");
console.log(`ON-INVOKE total (skill bodies, NOT startup): ~${tokens(onInvokeTotal)} tokens — only paid when the model reads a SKILL.md during a task`);

console.log("\n=== Skills: listing cost (STARTUP; name+description only) ===");
console.log("skill".padEnd(40), "source".padEnd(46), "listed".padStart(7));
for (const s of [...allSkills].sort((a, b) => b.listed - a.listed)) {
  console.log(s.name.padEnd(40), s.source.padEnd(46), String(tokens(s.listed)).padStart(7));
}

console.log("\n=== Skills: body cost (ON-INVOKE, NOT startup; full SKILL.md when read) ===");
console.log("skill".padEnd(40), "source".padEnd(46), "body".padStart(8), "path");
for (const s of allSkills) {
  console.log(s.name.padEnd(40), s.source.padEnd(46), String(tokens(s.body)).padStart(8), " " + s.filePath);
}

console.log("\n=== Skills by source (count / listed startup / body on-invoke) ===");
const skillBySource = new Map();
for (const s of allSkills) {
  const e = skillBySource.get(s.source) ?? { count: 0, listed: 0, body: 0 };
  e.count += 1;
  e.listed += s.listed;
  e.body += s.body;
  skillBySource.set(s.source, e);
}
for (const [src, e] of [...skillBySource.entries()].sort((a, b) => b[1].listed - a[1].listed)) {
  console.log(src.padEnd(46), String(e.count).padStart(4), "skills", String(tokens(e.listed)).padStart(7), "listed", String(tokens(e.body)).padStart(8), "body");
}

console.log("\n=== Tool-level breakdown (all startup) ===");
for (const g of [...groups.values()].sort((a, b) => b.totalChars - a.totalChars)) {
  if (g.tools.length === 0) continue;
  console.log(`\n-- ${g.label} --`);
  for (const t of [...g.tools].sort((a, b) => b.chars - a.chars)) {
    console.log(`  ${t.name.padEnd(40)} ${String(tokens(t.chars)).padStart(6)} tokens (${t.chars} chars)`);
  }
}

if (errors.length > 0) {
  console.log("\n=== Load errors ===");
  for (const e of errors) console.log(`  ${e.path}: ${e.error}`);
}

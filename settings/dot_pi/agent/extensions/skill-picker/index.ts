/**
 * Skill Picker — inline `$` autocomplete for skills anywhere in a prompt.
 *
 * Type `$` at the start of a word in a message to open an inline autocomplete
 * dropdown (exactly like the built-in `/` command and `@` file pickers). Keep
 * typing to fuzzy-filter; pick a skill and the token becomes `$<name> ` in the
 * editor. On submit, an `input` transform rewrites `$<name>` mentions:
 *
 * - A leading `$<name> <args>` (exact skill match) becomes `/skill:<name> <args>`,
 *   which pi expands natively and renders as a skill-invocation block.
 * - Mid-text `$<name>` tokens (exact skill match, word-boundary anchored) are
 *   expanded inline by this extension: the token is replaced with the same
 *   `<skill name=... location=...>...</skill>` block pi's own expansion emits,
 *   with the surrounding prompt text left intact. pi only expands `/skill:`
 *   when it starts the message, so mid-text expansion must be done here.
 *
 * Tokens only rewrite when `<name>` exactly matches a discovered skill, so
 * literal `$` usage (`$5`, `$PATH`, `$1`) passes through untouched.
 *
 * This replaces pi's default `/skill:name` command selector, which is turned off via
 * `enableSkillCommands: false` in settings.json (see this repo's `modify_settings.json`).
 * `/skill:name` *expansion* still works because pi expands it unconditionally.
 *
 * The dropdown shows plain skill names (no `skill:` prefix) and includes
 * `disable-model-invocation` skills, since those are exactly the ones meant to be
 * launched manually.
 *
 * Skill discovery mirrors pi's own default locations via the exported `loadSkills()`
 * helper: `~/.pi/agent/skills`, `~/.agents/skills`, and project `.pi/skills` /
 * `.agents/skills` up to the git root, plus add/remove (`-` prefix) entries from
 * `~/.pi/agent/settings.json`'s `skills` array. Skills contributed only via pi
 * packages or `--skill` CLI flags are not surfaced here.
 */

import { existsSync, readFileSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { getAgentDir, loadSkills, stripFrontmatter } from "@earendil-works/pi-coding-agent";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
	type AutocompleteItem,
	type AutocompleteProvider,
	type AutocompleteSuggestions,
	fuzzyFilter,
} from "@earendil-works/pi-tui";

const MAX_SUGGESTIONS = 20;

interface PickSkill {
	name: string;
	description: string;
	/** Absolute path to the skill's SKILL.md (needed for inline expansion). */
	filePath: string;
	/** Absolute path to the skill directory (referenced by the expansion block). */
	baseDir: string;
}

/** Expand a leading `~` and resolve relative to `cwd`. */
function resolvePathish(p: string, cwd: string): string {
	let out = p.trim();
	if (out === "~") out = homedir();
	else if (out.startsWith("~/")) out = join(homedir(), out.slice(2));
	return resolve(cwd, out);
}

/** Walk up from `startDir` looking for a `.git` entry; returns the repo root or null. */
function findGitRoot(startDir: string): string | null {
	let dir = resolve(startDir);
	for (;;) {
		if (existsSync(join(dir, ".git"))) return dir;
		const parent = dirname(dir);
		if (parent === dir) return null;
		dir = parent;
	}
}

/** Default skill directories pi scans, in the layout used on this machine. */
function defaultSkillDirs(cwd: string): string[] {
	const dirs: string[] = [];
	dirs.push(join(getAgentDir(), "skills")); // ~/.pi/agent/skills
	dirs.push(join(homedir(), ".agents", "skills")); // ~/.agents/skills
	const stop = findGitRoot(cwd);
	let dir = resolve(cwd);
	for (;;) {
		dirs.push(join(dir, ".pi", "skills"));
		dirs.push(join(dir, ".agents", "skills"));
		if (stop && dir === stop) break;
		const parent = dirname(dir);
		if (parent === dir) break;
		dir = parent;
	}
	return dirs;
}

/** Read add/remove skill entries from the global settings.json `skills` array. */
function readSettingsSkills(): { adds: string[]; removes: string[] } {
	const adds: string[] = [];
	const removes: string[] = [];
	try {
		const raw = JSON.parse(readFileSync(join(getAgentDir(), "settings.json"), "utf8")) as {
			skills?: unknown;
		};
		if (Array.isArray(raw.skills)) {
			for (const entry of raw.skills) {
				if (typeof entry !== "string") continue;
				if (entry.startsWith("-")) removes.push(entry.slice(1));
				else adds.push(entry);
			}
		}
	} catch {
		// No/invalid settings.json — fall back to defaults only.
	}
	return { adds, removes };
}

/** Discover selectable skills, mirroring pi's default resolution as closely as practical. */
function discoverSkills(cwd: string): PickSkill[] {
	const { adds, removes } = readSettingsSkills();
	const dirs = defaultSkillDirs(cwd).filter((d) => {
		try {
			return statSync(d).isDirectory();
		} catch {
			return false;
		}
	});
	const skillPaths = [...dirs, ...adds];

	let skills: { name: string; description: string; filePath: string; baseDir: string }[] = [];
	try {
		skills = loadSkills({ cwd, agentDir: getAgentDir(), skillPaths, includeDefaults: false }).skills;
	} catch {
		return [];
	}

	const removeResolved = removes.map((r) => resolvePathish(r, cwd));
	const isRemoved = (p: string) => {
		const rp = resolve(p);
		return removeResolved.some((rr) => rp === rr || rp.startsWith(`${rr}/`));
	};

	return skills
		.filter((s) => !isRemoved(s.filePath) && !isRemoved(s.baseDir))
		.map((s) => ({
			name: s.name,
			description: s.description ?? "",
			filePath: s.filePath,
			baseDir: s.baseDir,
		}))
		.sort((a, b) => a.name.localeCompare(b.name));
}

/**
 * Extract the skill filter token when the cursor is inside a `$…` mention.
 * The `$` must start the prompt, a line, or follow whitespace (so `foo$bar`,
 * emails, and `$PATH`-style identifiers mid-word don't trigger the picker).
 * Returns undefined when the `$` trigger does not apply.
 */
function extractSkillToken(lines: string[], cursorLine: number, cursorCol: number): string | undefined {
	const before = (lines[cursorLine] ?? "").slice(0, cursorCol);
	const match = before.match(/(?:^|\s)\$(\S*)$/); // word-boundary `$`, then non-space run up to the cursor.
	return match?.[1];
}

function toItem(skill: PickSkill): AutocompleteItem {
	return {
		value: `$${skill.name}`, // Inserted text; rewritten to /skill:<name> on submit.
		label: skill.name, // Shown without any prefix.
		description: skill.description,
	};
}

function filterSkills(skills: PickSkill[], query: string): AutocompleteItem[] {
	if (!query.trim()) return skills.slice(0, MAX_SUGGESTIONS).map(toItem);
	return fuzzyFilter(skills, query, (s) => `${s.name} ${s.description}`)
		.slice(0, MAX_SUGGESTIONS)
		.map(toItem);
}

/**
 * Expand every mid-text `$<name>` mention whose name exactly matches a known
 * skill, inlining the same `<skill …>` block pi's own `/skill:` expansion
 * emits. `$` must be preceded by start-of-string or whitespace and the token
 * must run to end-of-string or whitespace; trailing punctuation on the token
 * (`$grill-me,`) is tolerated. Unmatched tokens (literal `$5`, `$PATH`, unknown
 * names) pass through untouched.
 */
function expandInlineSkillMentions(text: string, skills: PickSkill[]): string {
	if (!skills.length) return text;
	const byName = new Map(skills.map((s) => [s.name, s]));
	const pattern = /(^|\s)\$(\S+)(?=\s|$)/g;
	let result = "";
	let lastIndex = 0;
	for (const match of text.matchAll(pattern)) {
		const token = match[2].replace(/[.,;:!?)]+$/, ""); // tolerate trailing punctuation
		const skill = byName.get(token);
		if (!skill) continue; // Not a skill — leave this mention literally.
		let body: string;
		try {
			body = stripFrontmatter(readFileSync(skill.filePath, "utf-8")).trim();
		} catch {
			continue; // Unreadable skill file — leave the mention literally.
		}
		const block =
			`<skill name="${skill.name}" location="${skill.filePath}">\n` +
			`References are relative to ${skill.baseDir}.\n\n${body}\n</skill>`;
		const start = (match.index ?? 0) + match[1].length; // keep the leading whitespace/start anchor
		const tokenEnd = match.index! + match[0].length; // end of `$<name>` (excludes look-ahead)
		result += text.slice(lastIndex, start) + block;
		lastIndex = tokenEnd;
	}
	if (lastIndex === 0) return text; // Nothing replaced.
	return result + text.slice(lastIndex);
}

function createSkillAutocompleteProvider(
	current: AutocompleteProvider,
	getSkills: () => PickSkill[],
): AutocompleteProvider {
	return {
		triggerCharacters: ["$"],

		async getSuggestions(lines, cursorLine, cursorCol, options): Promise<AutocompleteSuggestions | null> {
			const token = extractSkillToken(lines, cursorLine, cursorCol);
			if (token === undefined) {
				return current.getSuggestions(lines, cursorLine, cursorCol, options);
			}
			const items = filterSkills(getSkills(), token);
			if (items.length === 0) {
				return current.getSuggestions(lines, cursorLine, cursorCol, options);
			}
			return { items, prefix: `$${token}` };
		},

		applyCompletion(lines, cursorLine, cursorCol, item, prefix) {
			// Only handle our own `$…` completions; delegate everything else.
			if (!prefix.startsWith("$")) {
				return current.applyCompletion(lines, cursorLine, cursorCol, item, prefix);
			}
			const line = lines[cursorLine] ?? "";
			const before = line.slice(0, cursorCol);
			const after = line.slice(cursorCol);
			const start = before.length - prefix.length;
			// Insert `$<name> ` (trailing space closes the dropdown and lets args follow).
			const insert = `${item.value} `;
			const newLines = [...lines];
			newLines[cursorLine] = before.slice(0, start) + insert + after;
			return { lines: newLines, cursorLine, cursorCol: start + insert.length };
		},

		shouldTriggerFileCompletion(lines, cursorLine, cursorCol) {
			return current.shouldTriggerFileCompletion?.(lines, cursorLine, cursorCol) ?? true;
		},
	};
}

export default function (pi: ExtensionAPI): void {
	let skills: PickSkill[] = [];

	pi.on("session_start", (_event, ctx) => {
		skills = discoverSkills(ctx.cwd);
		ctx.ui.addAutocompleteProvider((current) => createSkillAutocompleteProvider(current, () => skills));
	});

	// On submit, rewrite `$<name>` mentions:
	// - Leading `$<name> <args>` → `/skill:<name> <args>` so pi expands it natively
	//   and renders it as a skill-invocation block.
	// - Mid-text `$<name>` → the skill block inlined by this extension (pi only
	//   expands `/skill:` when it starts the message).
	// Both fire only on exact skill-name matches, so literal `$` usage (e.g. `$5`)
	// passes through.
	pi.on("input", async (event) => {
		if (event.source === "extension") return;
		if (!event.text.includes("$")) return;
		if (event.text.startsWith("$")) {
			const match = event.text.slice(1).match(/^(\S+)([\s\S]*)$/);
			if (match) {
				const name = match[1];
				if (skills.some((s) => s.name === name)) {
					const args = (match[2] ?? "").trim();
					return { action: "transform", text: args ? `/skill:${name} ${args}` : `/skill:${name}` };
				}
			}
		}
		const expanded = expandInlineSkillMentions(event.text, skills);
		if (expanded !== event.text) {
			return { action: "transform", text: expanded };
		}
	});

	// Re-scan skills after `/reload` so newly added skills show up without a restart.
	pi.on("resources_discover", (event) => {
		if (event.reason === "reload") skills = discoverSkills(event.cwd);
	});
}

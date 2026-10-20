/**
 * judgekit — pi harness extension.
 *
 * Wraps the judgekit library (~/src/judgekit, import from its built dist)
 * with two model-callable tools:
 *
 *   judge — batch typed questions (noul/choice/score) about a state to a fast
 *           decision model; answers come back with confidence and escalation
 *   gate  — one allow/deny/escalate check on a proposed action
 *
 * Backends come from ~/.config/judgekit/config.json (JUDGEKIT_CONFIG
 * overrides the path). A profile's apiKeyCommand runs fresh per request, so
 * short-lived credentials stay valid in long sessions.
 *
 * When a step produces new text or code, that is the language model's job;
 * judge is for steps that only need a fast decision. Escalated verdicts carry
 * a hint and the model's answer as a prior.
 */

import { Type } from "typebox";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { gate, judge, readConfig, resolveBackend, type Config, type DecisionBackend } from "/Users/tatlas/src/judgekit/dist/index.js";

const QuestionSchema = Type.Union([
	Type.Object({
		type: Type.Literal("noul"),
		question: Type.String({ description: "The claim whose probability of being true is scored" }),
		criteria: Type.Optional(
			Type.Object({
				true: Type.String(),
				false: Type.String(),
			}),
		),
	}),
	Type.Object({
		type: Type.Literal("choice"),
		question: Type.String(),
		options: Type.Union([
			Type.Array(Type.String(), { minItems: 2 }),
			Type.Record(Type.String(), Type.String(), { minProperties: 2 }),
		]),
	}),
	Type.Object({
		type: Type.Literal("score"),
		question: Type.String(),
		levels: Type.Array(Type.String(), { minItems: 2 }),
	}),
]);

const backendCache = new Map<string, DecisionBackend>();

function backendFor(config: Config, name?: string): DecisionBackend {
	const key = name ?? config.default ?? Object.keys(config.backends)[0] ?? "";
	const cached = backendCache.get(key);
	if (cached) return cached;
	const backend = resolveBackend(config, key || undefined);
	backendCache.set(key, backend);
	return backend;
}

export default function (pi: ExtensionAPI) {
	pi.registerTool({
		name: "judge",
		label: "Judge",
		description:
			"Batch typed questions about one state to a fast decision model in a single call (~100-300ms). " +
			"Question types: noul (probability a claim is true), choice (pick one enumerated option), score (position on ordered levels). " +
			"Answers carry confidence and an escalate flag; a verdict below the confidence threshold hands the decision back to you as a prior, not a command. " +
			"Use this for steps that only need a fast decision — triage, routing, gating, pass/fail — never for steps that must produce new text or code.",
		parameters: Type.Object({
			state: Type.String({ description: "Everything the decision may consider: facts, tool output, file excerpts. Keep it under ~30k tokens." }),
			questions: Type.Record(Type.String(), QuestionSchema, { minProperties: 1, description: "Questions by answer name" }),
			backend: Type.Optional(Type.String({ description: "Backend name from the judgekit config; defaults to the configured default" })),
			model: Type.Optional(Type.String({ description: "Backend model override" })),
			confidence_threshold: Type.Optional(Type.Number({ description: "Escalate verdicts below this confidence (default 0.5 reported / 0.4 estimated)" })),
		}),
		async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
			const config = readConfig();
			const result = await judge(backendFor(config, params.backend), params.state, params.questions, {
				confidenceThreshold: params.confidence_threshold,
				model: params.model,
			});
			const escalated = result.verdicts.filter((v) => v.escalate);
			const lines = [
				`backend=${result.backend} model=${result.model ?? "?"} latency=${result.latencyMs}ms escalated=${result.escalated}`,
			];
			for (const verdict of result.verdicts) {
				lines.push(
					`${verdict.id}: ${JSON.stringify(verdict.answer)}${verdict.confidence !== undefined ? ` (confidence ${verdict.confidence.toFixed(2)}${verdict.confidenceFrom ? `, ${verdict.confidenceFrom}` : ""})` : ""}${verdict.escalate ? " ESCALATED" : ""}`,
				);
				if (verdict.distribution) lines.push(`  distribution: ${JSON.stringify(verdict.distribution)}`);
				if (verdict.hint) lines.push(`  hint: ${verdict.hint}`);
			}
			if (escalated.length > 0) {
				lines.push(
					`${escalated.length} of ${result.verdicts.length} verdicts escalated. Treat escalated answers as priors: reason the decision out yourself instead of acting on them.`,
				);
			}
			return {
				content: [{ type: "text", text: lines.join("\n") }],
				details: result,
			};
		},
	});

	pi.registerTool({
		name: "gate",
		label: "Gate",
		description:
			"Ask the decision model whether one proposed action is safe. Returns allow, deny, or escalate; allow only at confident-enough verdicts, so the gate can deny or hand back but never grant anything. " +
			"Input is credential-redacted before the call. Adds one short round trip per call, so gate actions worth gating, not everything.",
		parameters: Type.Object({
			state: Type.String({ description: "Current task context" }),
			tool: Type.String({ description: "The tool the action would run, e.g. Bash" }),
			input: Type.Any({ description: "The action's arguments, verbatim; credentials are redacted before judging" }),
			description: Type.Optional(Type.String({ description: "Intent, judged alongside the action" })),
			backend: Type.Optional(Type.String({ description: "Backend name from the judgekit config" })),
			confidence_threshold: Type.Optional(Type.Number({ description: "Escalate below this confidence (default 0.5 reported / 0.4 estimated)" })),
		}),
		async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
			const config = readConfig();
			const result = await gate(backendFor(config, params.backend), params.state, { tool: params.tool, input: params.input }, {
				confidenceThreshold: params.confidence_threshold,
				description: params.description,
			});
			const lines = [
				`decision: ${result.decision}${result.confidence !== undefined ? ` (confidence ${result.confidence.toFixed(2)}${result.confidenceFrom ? `, ${result.confidenceFrom}` : ""})` : ""}`,
			];
			if (result.hint) lines.push(`hint: ${result.hint}`);
			if (result.decision === "escalate") {
				lines.push("The gate did not decide. Apply your normal judgment and permission flow.");
			} else if (result.decision === "deny") {
				lines.push("The gate denied the action. Explain why and propose a safer alternative.");
			} else {
				lines.push("The gate allows the action; the normal permission flow still applies.");
			}
			return {
				content: [{ type: "text", text: lines.join("\n") }],
				details: result,
			};
		},
	});

	pi.registerCommand("judgekit-doctor", {
		description: "Resolve the judgekit config and run one live round trip",
		handler: async (_args, ctx) => {
			try {
				const config = readConfig();
				const backend = backendFor(config);
				const result = await judge(backend, "judgekit doctor", {
					ok: { type: "noul", question: "Is this a live round trip?" },
				});
				const verdict = result.verdicts[0];
				const message =
					verdict.reason === "unreachable"
						? `judgekit: backend ${result.backend} unreachable`
						: `judgekit: ${result.backend} responded in ${result.latencyMs}ms (${result.verdicts.length} question)`;
				if (ctx.hasUI) ctx.ui.notify(message, verdict.reason === "unreachable" ? "error" : "info");
				else console.log(message);
			} catch (error) {
				const message = `judgekit: ${error instanceof Error ? error.message : String(error)}`;
				if (ctx.hasUI) ctx.ui.notify(message, "error");
				else console.error(message);
			}
		},
	});
}

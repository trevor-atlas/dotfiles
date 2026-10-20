/**
 * litellm-models — dynamic LiteLLM model catalog for pi
 *
 * Registers a dynamic `litellm` provider whose model list is refreshed from
 * the HubSpot LiteLLM proxy (/model/info). Replaces the pi-provider-litellm
 * extension with ~100 lines instead of ~3k.
 *
 * - The native `litellm` provider in ~/.pi/agent/models.json supplies auth
 *   (!hsauthctl idp get-token) and a small static fallback model list that
 *   --no-extensions subagent sandboxes can still resolve.
 * - This extension refreshes the catalog at startup and persists it to
 *   models-store.json (via publish({ persist })). The static list is only
 *   used until the first successful refresh.
 * - TTL: refreshes hit the network at most once per TTL window; use
 *   /litellm-refresh to force an immediate refresh.
 *
 * Env: LITELLM_MODELS_TTL_MS overrides the TTL (default 6h).
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import type { ProviderModelConfig, RefreshModelsContext } from "@mariozechner/pi-ai";

const PROXY_BASE = "https://litellm.hubteamqa.com";
const TTL_MS = Number(process.env.LITELLM_MODELS_TTL_MS) || 6 * 60 * 60 * 1000;

interface ModelInfo {
	mode?: string;
	max_input_tokens?: number;
	max_output_tokens?: number;
	max_tokens?: number;
	supports_reasoning?: boolean;
	supports_vision?: boolean;
	pi_supports_reasoning_effort?: boolean;
	pi_thinking_format?: string;
	input_cost_per_token?: number | null;
	output_cost_per_token?: number | null;
	cache_read_input_token_cost?: number | null;
	cache_creation_input_token_cost?: number | null;
}

interface ModelInfoResponse {
	model_name?: string;
	model_info?: ModelInfo;
}

function toProviderModel(id: string, info: ModelInfo): ProviderModelConfig {
	const reasoning = Boolean(info.supports_reasoning || info.pi_supports_reasoning_effort);
	const compat: Record<string, unknown> = {};
	// Anthropic models behind the proxy need anthropic-style cache control.
	if (id.startsWith("anthropic/")) {
		compat.cacheControlFormat = "anthropic";
		compat.supportsStore = false;
	}
	if (info.pi_thinking_format === "zai") {
		compat.thinkingFormat = "zai";
	}
	if (info.pi_supports_reasoning_effort) {
		compat.supportsReasoningEffort = true;
	}
	const model: ProviderModelConfig = {
		id,
		name: id,
		reasoning,
		input: info.supports_vision ? ["text", "image"] : ["text"],
		contextWindow: info.max_input_tokens ?? 128000,
		maxTokens: info.max_output_tokens ?? info.max_tokens ?? 16384,
	};
	if (info.input_cost_per_token != null && info.output_cost_per_token != null) {
		// pi costs are $/1M tokens; the proxy reports $/token.
		model.cost = {
			input: info.input_cost_per_token * 1e6,
			output: info.output_cost_per_token * 1e6,
			cacheRead: (info.cache_read_input_token_cost ?? 0) * 1e6,
			cacheWrite: (info.cache_creation_input_token_cost ?? 0) * 1e6,
		};
	}
	if (Object.keys(compat).length > 0) {
		model.compat = compat as ProviderModelConfig["compat"];
	}
	return model;
}

async function fetchCatalog(apiKey: string, signal: AbortSignal): Promise<ProviderModelConfig[]> {
	const response = await fetch(`${PROXY_BASE}/model/info`, {
		headers: { Authorization: `Bearer ${apiKey}` },
		signal,
	});
	if (!response.ok) {
		throw new Error(`LiteLLM /model/info returned HTTP ${response.status}`);
	}
	const body = (await response.json()) as ModelInfoResponse[] | { data?: ModelInfoResponse[] };
	const entries = Array.isArray(body) ? body : (body.data ?? []);
	const seen = new Set<string>();
	const models: ProviderModelConfig[] = [];
	for (const entry of entries) {
		const id = entry.model_name ?? (entry.model_info as { id?: string } | undefined)?.id;
		const info = entry.model_info;
		if (!id || !info || seen.has(id)) continue;
		if (info.mode !== "chat" || id.includes("*")) continue; // skip non-chat + wildcard aliases
		seen.add(id);
		models.push(toProviderModel(id, info));
	}
	models.sort((a, b) => a.id.localeCompare(b.id));
	return models;
}

export default function (pi: ExtensionAPI) {
	pi.registerProvider("litellm", {
		name: "LiteLLM",
		baseUrl: `${PROXY_BASE}/v1`,
		api: "openai-completions",
		// No `models` here: models.json's static fallback stays in place until
		// the first refresh publishes the live catalog.
		refreshModels: async (context: RefreshModelsContext): Promise<ProviderModelConfig[] | undefined> => {
			if (process.env.LITELLM_DEBUG) {
				console.error(`[litellm] allowNetwork=${context.allowNetwork} force=${context.force} cred=${context.credential ? `api_key key=<${(context.credential as { key?: string }).key?.length ?? 0} chars>` : "none"} stored=${context.stored ? `${context.stored.models?.length} models @${new Date(context.stored.checkedAt).toISOString()}` : "none"}`);
			}
			// Cache-only phase: restore the persisted catalog if we have one.
			// Returning undefined (not []) leaves the models.json static fallback in
			// place — the composer replaces the whole model list with any truthy
			// return value, so [] would wipe the provider to zero models.
			if (!context.allowNetwork) return context.stored?.models;
			const stored = context.stored?.models;
			const checkedAt = context.stored?.checkedAt ?? 0;
			// Network phase: respect the TTL unless forced. While fresh, hand back
			// the persisted catalog so startup is fast (no fetch) and the catalog
			// can never regress to an empty list.
			if (!context.force && Date.now() - checkedAt < TTL_MS) return stored;
			// The resolved token lives at credential.key (ApiKeyCredential), not apiKey.
			const apiKey =
				(context.credential as { key?: string } | undefined)?.key ??
				(context.credential as { apiKey?: string } | undefined)?.apiKey;
			if (!apiKey) return stored;
			const models = await fetchCatalog(apiKey, context.signal);
			if (models.length === 0) return stored;
			await context.publish({ persist: { models, checkedAt: Date.now() } });
			return models;
		},
	});

	pi.registerCommand("litellm-refresh", {
		description: "Force-refresh the LiteLLM model catalog",
		handler: async (_args, ctx) => {
			const result = await ctx.modelRegistry.refresh({ providers: ["litellm"], force: true });
			const models = ctx.modelRegistry
				.getAvailable()
				.filter((m) => m.provider === "litellm");
			const error = result.errors.get("litellm");
			const message = error
				? `LiteLLM refresh failed: ${error.message}`
				: `LiteLLM catalog refreshed (${models.length} models)`;
			if (ctx.hasUI) ctx.ui.notify(message, error ? "error" : "info");
			else console.log(message);
			if (!error) {
				const listing = models.map((m) => m.id).join("\n");
				if (ctx.hasUI) ctx.ui.notify(listing || "(no models)", "info");
				else console.log(listing || "(no models)");
			}
		},
	});
}

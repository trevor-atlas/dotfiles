/**
 * jetway-models — dynamic Jetway model catalogs for pi
 *
 * Registers one provider per API surface Jetway serves that pi can speak
 * (https://github.com/HubSpotEngineering/jetway — HubSpot's internal LLM proxy
 * for OpenAI/Anthropic/Baseten). Mirrors litellm-models.ts:
 *
 *   jetway           → OpenAI Chat Completions surface  (…/v1/chat/completions)
 *   jetway-anthropic → Anthropic Messages surface       (…/v1/messages)
 *
 * Jetway never translates between API surfaces; each model declares the
 * surfaces it serves in /v1/models metadata (metadata.apis), so each provider
 * lists only the models tagged with its surface. The System One surface
 * (clef/clef-flash) has no pi chat API, so it is not registered.
 *
 * - The native providers in ~/.pi/agent/models.json supply auth
 *   (!hsauthctl idp get-token) and static fallback model lists that
 *   --no-extensions subagent sandboxes can still resolve.
 * - The extensions refresh catalogs from /v1/models at startup and persist
 *   them to models-store.json (via publish({ persist })). The static lists are
 *   only used until the first successful refresh.
 * - TTL: refreshes hit the network at most once per TTL window; use
 *   /jetway-refresh to force an immediate refresh.
 *
 * Jetway rejects proxied requests without a non-blank x-hubspot-ai-origin-id
 * header (400 missing_origin_id), so it is set on every provider. Requests run
 * under your personal Infra IDP identity and jetway's per-identity rate limits.
 * Internal jetway serves models that lack data-residency/subprocessor
 * guarantees — internal, non-customer-data traffic only.
 *
 * Env: JETWAY_MODELS_TTL_MS overrides the TTL (default 6h).
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import type { ProviderModelConfig, RefreshModelsContext } from "@mariozechner/pi-ai";

const PROXY_HOST = "https://service-mainline.app-jetway-internal-web.svc.iad03.k8s.run";
const ORIGIN_ID = "pi:jetway";
const TTL_MS = Number(process.env.JETWAY_MODELS_TTL_MS) || 6 * 60 * 60 * 1000;

const DEFAULT_CONTEXT_WINDOW = 128000;
const DEFAULT_MAX_TOKENS = 16384;
// GLM (Baseten, HubSpot-hosted): matches the litellm static config.
const GLM_CONTEXT_WINDOW = 1048576;
const GLM_MAX_TOKENS = 262144;
// GPT via the internal OpenAI project: matches the litellm gpt-5.6-luna sizing.
const GPT_CONTEXT_WINDOW = 400000;
const GPT_MAX_TOKENS = 128000;
// EAP Anthropic models: sizing not published by jetway; standard Claude sizing.
const ANTHROPIC_CONTEXT_WINDOW = 200000;
const ANTHROPIC_MAX_TOKENS = 64000;
// Models jetway serves as unlisted default-backend passthroughs: /v1/models
// does not name them, but inference works. Merged into the refreshed OpenAI
// catalog so a refresh cannot drop them from the picker.
const KNOWN_UNLISTED_MODELS = ["gpt-6-luna"];

interface SurfaceConfig {
	providerId: string;
	api: "openai-completions" | "anthropic-messages";
	/** pi model.baseUrl for this surface (anthropic SDK appends /v1/messages itself). */
	baseUrl: string;
	/** metadata.apis tags a model must include to be listed on this surface. */
	apis: string[];
}

const SURFACES: SurfaceConfig[] = [
	{ providerId: "jetway", api: "openai-completions", baseUrl: `${PROXY_HOST}/v1`, apis: ["openai"] },
	{ providerId: "jetway-anthropic", api: "anthropic-messages", baseUrl: PROXY_HOST, apis: ["anthropic"] },
];

interface JetwayModelMetadata {
	apis?: string[];
	wildcard?: boolean;
	description?: string | null;
	tags?: string[];
}

interface JetwayPricing {
	prompt?: number;
	completion?: number;
	input_cache_read?: number;
}

interface JetwayModelEntry {
	id?: string;
	owned_by?: string;
	metadata?: JetwayModelMetadata;
	pricing?: JetwayPricing;
}

function toProviderModel(id: string, surface: SurfaceConfig, pricing?: JetwayPricing): ProviderModelConfig {
	let contextWindow = DEFAULT_CONTEXT_WINDOW;
	let maxTokens = DEFAULT_MAX_TOKENS;
	let input: ProviderModelConfig["input"] = ["text"];
	const compat: Record<string, unknown> = {};
	if (surface.api === "anthropic-messages") {
		contextWindow = ANTHROPIC_CONTEXT_WINDOW;
		maxTokens = ANTHROPIC_MAX_TOKENS;
		input = ["text", "image"];
	} else {
		const glm = id.toUpperCase().includes("GLM");
		const gpt = id.toLowerCase().startsWith("gpt-");
		contextWindow = glm ? GLM_CONTEXT_WINDOW : gpt ? GPT_CONTEXT_WINDOW : DEFAULT_CONTEXT_WINDOW;
		maxTokens = glm ? GLM_MAX_TOKENS : gpt ? GPT_MAX_TOKENS : DEFAULT_MAX_TOKENS;
		if (gpt) input = ["text", "image"];
		if (glm) {
			compat.thinkingFormat = "zai";
			compat.supportsReasoningEffort = true;
		}
	}
	const model: ProviderModelConfig = {
		id,
		name: id,
		reasoning: true,
		input,
		contextWindow,
		maxTokens,
	};
	if (pricing?.prompt != null && pricing?.completion != null) {
		// pi costs are $/1M tokens; Jetway pricing is USD per token.
		model.cost = {
			input: pricing.prompt * 1e6,
			output: pricing.completion * 1e6,
			cacheRead: (pricing.input_cache_read ?? 0) * 1e6,
			cacheWrite: 0,
		};
	}
	if (Object.keys(compat).length > 0) {
		model.compat = compat as ProviderModelConfig["compat"];
	}
	return model;
}

async function fetchCatalog(apiKey: string, surface: SurfaceConfig, signal: AbortSignal): Promise<ProviderModelConfig[]> {
	const response = await fetch(`${PROXY_HOST}/v1/models`, {
		headers: { Authorization: `Bearer ${apiKey}` },
		signal,
	});
	if (!response.ok) {
		throw new Error(`Jetway /v1/models returned HTTP ${response.status}`);
	}
	const body = (await response.json()) as JetwayModelEntry[] | { data?: JetwayModelEntry[] };
	const entries = Array.isArray(body) ? body : (body.data ?? []);
	const seen = new Set<string>();
	const models: ProviderModelConfig[] = [];
	for (const entry of entries) {
		const id = entry.id;
		const metadata = entry.metadata;
		if (!id || seen.has(id)) continue;
		// Jetway never translates between API surfaces; only list models that
		// declare this surface. System One models are not listed anywhere.
		if (!surface.apis.some((api) => metadata?.apis?.includes(api))) continue;
		if (metadata?.wildcard || id.includes("*")) continue; // wildcard ids are patterns, not sendable names
		seen.add(id);
		models.push(toProviderModel(id, surface, entry.pricing));
	}
	if (surface.providerId === "jetway") {
		for (const id of KNOWN_UNLISTED_MODELS) {
			if (!seen.has(id)) {
				seen.add(id);
				models.push(toProviderModel(id, surface));
			}
		}
	}
	models.sort((a, b) => a.id.localeCompare(b.id));
	return models;
}

export default function (pi: ExtensionAPI) {
	for (const surface of SURFACES) {
		pi.registerProvider(surface.providerId, {
			name: surface.providerId === "jetway" ? "Jetway" : "Jetway (Anthropic)",
			baseUrl: surface.baseUrl,
			api: surface.api,
			headers: { "x-hubspot-ai-origin-id": ORIGIN_ID },
			// No `models` here: models.json's static fallback stays in place until
			// the first refresh publishes the live catalog.
			refreshModels: async (context: RefreshModelsContext): Promise<ProviderModelConfig[] | undefined> => {
				if (process.env.JETWAY_DEBUG) {
					console.error(`[${surface.providerId}] allowNetwork=${context.allowNetwork} force=${context.force} cred=${context.credential ? `api_key key=<${(context.credential as { key?: string }).key?.length ?? 0} chars>` : "none"} stored=${context.stored ? `${context.stored.models?.length} models @${new Date(context.stored.checkedAt).toISOString()}` : "none"}`);
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
				const models = await fetchCatalog(apiKey, surface, context.signal);
				if (models.length === 0) return stored;
				await context.publish({ persist: { models, checkedAt: Date.now() } });
				return models;
			},
		});
	}

	pi.registerCommand("jetway-refresh", {
		description: "Force-refresh the Jetway model catalogs",
		handler: async (_args, ctx) => {
			const providers = SURFACES.map((surface) => surface.providerId);
			const result = await ctx.modelRegistry.refresh({ providers, force: true });
			const lines: string[] = [];
			for (const surface of SURFACES) {
				const error = result.errors.get(surface.providerId);
				if (error) {
					lines.push(`${surface.providerId}: refresh failed — ${error.message}`);
					continue;
				}
				const models = ctx.modelRegistry
					.getAvailable()
					.filter((m) => m.provider === surface.providerId);
				lines.push(`${surface.providerId}: ${models.length} models`);
				for (const model of models) lines.push(`  ${model.id}`);
			}
			const message = lines.join("\n");
			if (ctx.hasUI) ctx.ui.notify(message, "info");
			else console.log(message);
		},
	});
}

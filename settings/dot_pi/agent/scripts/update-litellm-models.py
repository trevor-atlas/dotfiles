#!/usr/bin/env python3
"""Regenerate the `litellm` provider's model list in ~/.pi/agent/models.json.

Fetches the model catalog from the HubSpot LiteLLM proxy (/model/info), keeps
chat models only, and merges them into the `litellm` provider entry. Other
providers (anthropic, openai, ...) are left untouched.

Run after `chezmoi apply` (which re-renders models.json from models.json.tmpl).
Requires `hsauthctl` for the IdP token.

Usage: update-litellm-models.py [--models-json PATH] [--dry-run]
"""

import argparse
import json
import os
import subprocess
import sys
import urllib.request

DEFAULT_MODELS_JSON = os.path.expanduser("~/.pi/agent/models.json")
PROXY_BASE = "https://litellm.hubteamqa.com"
API_KEY_CMD = ["hsauthctl", "idp", "get-token"]

# Ids that are wildcard/aggregate aliases, not real models.
WILDCARD_PATTERNS = ("/*", "lm_studio_")


def get_token() -> str:
    out = subprocess.run(API_KEY_CMD, capture_output=True, text=True, check=True)
    return out.stdout.strip()


def fetch_catalog(token: str) -> list[dict]:
    req = urllib.request.Request(
        f"{PROXY_BASE}/model/info", headers={"Authorization": f"Bearer {token}"}
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        body = json.load(resp)
    return body.get("data", body) if isinstance(body, dict) else body


def select_models(catalog: list[dict]) -> list[dict]:
    """Keep chat-mode models with concrete ids, deduplicated by id."""
    seen: set[str] = set()
    picked: list[dict] = []
    for entry in catalog:
        info = entry.get("model_info") or {}
        model_id = entry.get("model_name") or info.get("id")
        if not model_id or model_id in seen:
            continue
        if info.get("mode") != "chat":
            continue
        if any(p in model_id for p in WILDCARD_PATTERNS):
            continue
        seen.add(model_id)
        picked.append(
            {
                "id": model_id,
                "info": info,
                "description": info.get("description") or "",
            }
        )
    picked.sort(key=lambda m: m["id"])
    return picked


def to_pi_model(item: dict) -> dict:
    info = item["info"]
    context = info.get("max_input_tokens") or 128000
    max_out = info.get("max_output_tokens") or info.get("max_tokens") or 16384
    reasoning = bool(
        info.get("supports_reasoning") or info.get("pi_supports_reasoning_effort")
    )
    model: dict = {
        "id": item["id"],
        "name": f"{item['id']} (litellm)",
        "reasoning": reasoning,
        "input": ["text", "image"] if info.get("supports_vision") else ["text"],
        "contextWindow": context,
        "maxTokens": max_out,
    }
    in_cost = info.get("input_cost_per_token")
    out_cost = info.get("output_cost_per_token")
    cache_read = info.get("cache_read_input_token_cost")
    if in_cost is not None and out_cost is not None:
        cost: dict = {
            "input": round(in_cost * 1e6, 4),
            "output": round(out_cost * 1e6, 4),
        }
        if cache_read is not None:
            cost["cacheRead"] = round(cache_read * 1e6, 6)
        model["cost"] = cost
    # Anthropic models behind the proxy need anthropic-style cache control.
    if item["id"].startswith("anthropic/"):
        model["compat"] = {"cacheControlFormat": "anthropic", "supportsStore": False}
    return model


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--models-json", default=DEFAULT_MODELS_JSON)
    ap.add_argument("--dry-run", action="store_true", help="print the plan, don't write")
    args = ap.parse_args()

    try:
        token = get_token()
    except FileNotFoundError:
        print("error: hsauthctl not found", file=sys.stderr)
        return 1
    try:
        with open(args.models_json) as f:
            config = json.load(f)
    except FileNotFoundError:
        print(f"error: {args.models_json} not found", file=sys.stderr)
        return 1

    if "litellm" not in config.get("providers", {}):
        print(
            "error: no 'litellm' provider in models.json — add one via models.json.tmpl first",
            file=sys.stderr,
        )
        return 1

    picked = select_models(fetch_catalog(token))
    if not picked:
        print("error: proxy returned no chat models", file=sys.stderr)
        return 1

    models = [to_pi_model(item) for item in picked]
    config["providers"]["litellm"]["models"] = models
    # all-litellm was a stale hand-made alias; the litellm provider supersedes it.
    config["providers"].pop("all-litellm", None)

    if args.dry_run:
        print(json.dumps(models, indent=2)[:2000])
        print(f"... {len(models)} models total (dry run, nothing written)")
        return 0

    with open(args.models_json, "w") as f:
        json.dump(config, f, indent=2)
        f.write("\n")
    print(f"wrote {len(models)} litellm models to {args.models_json}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

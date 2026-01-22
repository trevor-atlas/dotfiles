#!/usr/bin/env bun
/**
 * PAI Hook Injection Script
 * 
 * Restores PAI hooks and environment variables to ~/.claude/settings.json
 * Run this after your employer's system management resets the Claude config.
 * 
 * Usage: bun run ~/.config/atlas/pai/inject-hooks.ts
 */

import { existsSync, readFileSync, writeFileSync, mkdirSync } from 'fs';
import { join } from 'path';
import { homedir } from 'os';

const PAI_DIR = join(homedir(), '.config', 'atlas', 'pai');
const CLAUDE_DIR = join(homedir(), '.claude');
const SETTINGS_PATH = join(CLAUDE_DIR, 'settings.json');

// PAI hooks to inject
const PAI_HOOKS = {
  SessionStart: [
    {
      matcher: "*",
      hooks: [
        { type: "command", command: `bun run ${PAI_DIR}/hooks/initialize-session.ts` },
        { type: "command", command: `bun run ${PAI_DIR}/hooks/load-core-context.ts` }
      ]
    }
  ],
  UserPromptSubmit: [
    {
      matcher: "*",
      hooks: [
        { type: "command", command: `bun run ${PAI_DIR}/hooks/update-tab-titles.ts` }
      ]
    }
  ]
};

// PAI security hook to inject into PreToolUse Bash
const PAI_SECURITY_HOOK = {
  type: "command",
  command: `bun run ${PAI_DIR}/hooks/security-validator.ts`
};

// PAI environment variables
const PAI_ENV = {
  DA: "Oni",
  TIME_ZONE: "America/New_York",
  PAI_DIR: PAI_DIR,
  PAI_SOURCE_APP: "Oni"
};

function main() {
  console.log("🔧 PAI Hook Injection Script");
  console.log(`   PAI_DIR: ${PAI_DIR}`);
  console.log(`   Target: ${SETTINGS_PATH}`);
  console.log("");

  // Ensure ~/.claude exists
  if (!existsSync(CLAUDE_DIR)) {
    mkdirSync(CLAUDE_DIR, { recursive: true });
    console.log("✓ Created ~/.claude directory");
  }

  // Read existing settings or create empty object
  let settings: Record<string, any> = {};
  if (existsSync(SETTINGS_PATH)) {
    try {
      settings = JSON.parse(readFileSync(SETTINGS_PATH, 'utf-8'));
      console.log("✓ Loaded existing settings.json");
    } catch (e) {
      console.log("⚠ Could not parse existing settings.json, starting fresh");
    }
  } else {
    console.log("✓ No existing settings.json, creating new one");
  }

  // Merge environment variables
  settings.env = { ...settings.env, ...PAI_ENV };
  console.log("✓ Merged PAI environment variables");

  // Initialize hooks if not present
  if (!settings.hooks) {
    settings.hooks = {};
  }

  // Add PAI hooks (SessionStart, UserPromptSubmit)
  for (const [event, hooks] of Object.entries(PAI_HOOKS)) {
    if (!settings.hooks[event]) {
      settings.hooks[event] = hooks;
      console.log(`✓ Added ${event} hooks`);
    } else {
      // Check if PAI hooks already exist
      const existingCommands = JSON.stringify(settings.hooks[event]);
      if (!existingCommands.includes(PAI_DIR)) {
        settings.hooks[event] = [...hooks, ...settings.hooks[event]];
        console.log(`✓ Merged ${event} hooks (PAI first)`);
      } else {
        console.log(`⊘ ${event} hooks already contain PAI hooks`);
      }
    }
  }

  // Add security validator to PreToolUse Bash
  if (!settings.hooks.PreToolUse) {
    settings.hooks.PreToolUse = [
      {
        matcher: "Bash",
        hooks: [PAI_SECURITY_HOOK]
      }
    ];
    console.log("✓ Added PreToolUse security hook");
  } else {
    // Find Bash matcher and add security hook if not present
    const bashMatcher = settings.hooks.PreToolUse.find(
      (h: any) => h.matcher === "Bash"
    );
    if (bashMatcher) {
      const existingCommands = JSON.stringify(bashMatcher.hooks);
      if (!existingCommands.includes('security-validator')) {
        bashMatcher.hooks = [PAI_SECURITY_HOOK, ...bashMatcher.hooks];
        console.log("✓ Added security validator to PreToolUse Bash");
      } else {
        console.log("⊘ Security validator already present");
      }
    } else {
      settings.hooks.PreToolUse.unshift({
        matcher: "Bash",
        hooks: [PAI_SECURITY_HOOK]
      });
      console.log("✓ Added new PreToolUse Bash matcher with security hook");
    }
  }

  // Write settings
  writeFileSync(SETTINGS_PATH, JSON.stringify(settings, null, 2) + '\n');
  console.log("");
  console.log("✅ PAI hooks injected successfully!");
  console.log("   Restart Claude Code to activate.");
}

main();

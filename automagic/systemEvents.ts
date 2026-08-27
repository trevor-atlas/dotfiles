/**
 * systemEvents: the system-event vocabulary + the one shared bus.
 *
 * The bus (`systemBus`) is generic — a dumb receive/broadcast transport that can
 * carry any events. This module is where those events are *declared*; today the
 * vocabulary is call state (`SystemEvent`), but nothing here is call-locked: a
 * new kind of event (mic audio, a calendar feed, screen state, …) is just
 * another member of the union and another producer publishing it.
 *
 * Producers (see `callDetector.ts` for the call source) are self-contained and
 * publish to `systemBus`; a consumer (see `busyAutomation.ts` for the bar's call
 * behavior) subscribes and reacts however it wants — possibly several consumers
 * doing unrelated things. Adding a source or consumer never changes this module.
 *
 * Generic bus machinery (the dumb `EventBus`, `createEventBus`) lives in `./eventBus`.
 */

import { EventBus } from './eventBus';
import type { CallApp } from './callDetector';

/** Semantic system events the bus can carry. */
export type SystemEvent =
  | { type: 'call_started'; app: CallApp }
  | { type: 'call_ended'; app: CallApp }
  // Full-state snapshot: what is true *right now*, not a change.
  // `app === null` means no call live. Consumers use it to learn current state.
  | { type: 'call_state_changed'; app: CallApp | null };
// Future events (not yet emitted) could look like:
//   | { type: 'mic_active' }
//   | { type: 'calendar_meeting_started'; title: string }

/** Payload of the `call_state_changed` full-state event. */
export type CallState = { app: CallApp | null };

/**
 * The shared, application-wide bus. Every detector publishes here; every
 * consumer subscribes here. Type parameter ties it to {@link SystemEvent}.
 * The bus itself is the dumb `EventBus` from `./eventBus` — receive + broadcast.
 */
export const systemBus = new EventBus<SystemEvent>();


// PAI Observability Stub
// Provides required interfaces when full observability server is not installed

interface ObservabilityEvent {
  source_app: string;
  session_id: string;
  hook_event_type: string;
  timestamp: string;
  [key: string]: any;
}

export function getSourceApp(): string {
  return process.env.DA || process.env.PAI_SOURCE_APP || 'Oni';
}

export function getCurrentTimestamp(): string {
  return new Date().toISOString();
}

export async function sendEventToObservability(event: ObservabilityEvent): Promise<void> {
  // Stub: logs to stderr when observability server is not running
  // Install pai-observability-server pack for full dashboard functionality
  if (process.env.PAI_DEBUG === 'true') {
    console.error(`[PAI:Observability] ${event.hook_event_type}: ${event.session_id}`);
  }
}

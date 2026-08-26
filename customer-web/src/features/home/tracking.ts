type EventType = "IMPRESSION" | "TAP";

interface QueuedEvent {
  clientUuid: string;
  eventType: EventType;
  productId: string;
  source: string;
  occurredAt: string;
}

const BATCH_SIZE = 20;
const FLUSH_DELAY_MS = 2000;

const queue: QueuedEvent[] = [];
let flushTimer: ReturnType<typeof setTimeout> | null = null;
const seen = new Set<string>();

function uuid(): string {
  if (typeof crypto !== "undefined" && "randomUUID" in crypto) return crypto.randomUUID();
  return `xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx`.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    return (c === "x" ? r : (r & 0x3) | 0x8).toString(16);
  });
}

function flush(): void {
  if (flushTimer) {
    clearTimeout(flushTimer);
    flushTimer = null;
  }
  if (queue.length === 0) return;
  const events = queue.splice(0, queue.length);
  void fetch("/api/home/events", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ events }),
    keepalive: true,
  }).catch(() => {
  });
}

function enqueue(eventType: EventType, productId: string, source: string): void {
  if (!productId) return;
  const key = `${eventType}:${productId}`;
  if (eventType === "IMPRESSION") {
    if (seen.has(key)) return;
    seen.add(key);
  }
  queue.push({ clientUuid: uuid(), eventType, productId, source, occurredAt: new Date().toISOString() });
  if (queue.length >= BATCH_SIZE) {
    flush();
  } else if (!flushTimer) {
    flushTimer = setTimeout(flush, FLUSH_DELAY_MS);
  }
}

export function recordImpression(productId: string, source = "home"): void {
  enqueue("IMPRESSION", productId, source);
}

export function recordTap(productId: string, source = "home"): void {
  enqueue("TAP", productId, source);
}

export function flushEvents(): void {
  flush();
}

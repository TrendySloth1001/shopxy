/**
 * Batched product-event tracker — a web port of the Flutter `TrackingService`.
 * Queues impressions/taps and flushes to the BFF (`POST /api/home/events`) when
 * the queue crosses the batch size OR a debounce timer fires, whichever first.
 * Best-effort: failures are swallowed (the backend dedupes on `clientUuid`).
 *
 * Module-level singleton so a single in-memory queue is shared across the feed
 * components (matches the app-wide service in the mobile app).
 */

type EventType = "IMPRESSION" | "TAP";

interface QueuedEvent {
  clientUuid: string;
  eventType: EventType;
  productId: number;
  source: string;
  occurredAt: string;
}

const BATCH_SIZE = 20;
const FLUSH_DELAY_MS = 2000;

const queue: QueuedEvent[] = [];
let flushTimer: ReturnType<typeof setTimeout> | null = null;
/** De-dupe within the session so an impression fires once per product/type. */
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
  // Keepalive lets the POST survive a navigation away from the page.
  void fetch("/api/home/events", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ events }),
    keepalive: true,
  }).catch(() => {
    /* best-effort */
  });
}

function enqueue(eventType: EventType, productId: number, source: string): void {
  if (!Number.isInteger(productId) || productId <= 0) return;
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

export function recordImpression(productId: number, source = "home"): void {
  enqueue("IMPRESSION", productId, source);
}

export function recordTap(productId: number, source = "home"): void {
  enqueue("TAP", productId, source);
}

/** Flush immediately — call when the page is hidden / unmounted. */
export function flushEvents(): void {
  flush();
}

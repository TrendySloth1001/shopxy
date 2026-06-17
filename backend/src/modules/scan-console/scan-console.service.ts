import { randomBytes } from 'node:crypto';
import type { Server as HttpServer, IncomingMessage } from 'node:http';
import type { Duplex } from 'node:stream';
import { WebSocketServer, WebSocket } from 'ws';
import { logger } from '../../shared/logging/logger.js';

/**
 * Scan-console realtime backbone (PROTOTYPE).
 *
 * A merchant opens the QR/barcode scanner on the Flutter app and each scan is
 * POSTed to `/me/scan-console/scan`; the resolved product is then pushed live
 * to every web console open for that shop over a WebSocket. The web console is
 * a pure *receiver* (one-directional server→browser), so only it holds a
 * socket — the phone publishes over plain REST.
 *
 * Scope is the **shop**: a scan fans out to anyone subscribed to that shopId.
 *
 * PROTOTYPE LIMITS (single-instance only — see PENDING / production notes):
 *   • Rooms + tickets live in-process. Behind >1 node the fan-out won't reach
 *     sockets on another instance — swap this Map for a Redis pub/sub channel
 *     keyed by shopId.
 *   • No scan history/replay: a console that connects after a scan misses it.
 */

// ── Realtime payloads (mirrored by the web client's zod schema) ───────────────

export type ScanItem = {
  /** Unique per scan event (not the product id) so the client can key a list. */
  scanId: string;
  productId: number;
  name: string;
  sku: string;
  barcode: string | null;
  /** Decimal serialised to a string by the controller. */
  sellingPrice: string;
  mrp: string | null;
  imageUrl: string | null;
  /** ISO timestamp the scan was received. */
  scannedAt: string;
  /** userId of the team member who scanned (shop-wide consoles show all). */
  scannedBy: number;
};

export type ScanConsoleEvent =
  | { type: 'connected'; shopId: number }
  | { type: 'scan'; scan: ScanItem }
  | { type: 'clear'; by: number };

// ── Subscriber hub: shopId → set of live sockets ─────────────────────────────

class ScanConsoleHub {
  private readonly rooms = new Map<number, Set<WebSocket>>();

  subscribe(shopId: number, ws: WebSocket): void {
    let room = this.rooms.get(shopId);
    if (!room) {
      room = new Set();
      this.rooms.set(shopId, room);
    }
    room.add(ws);
  }

  unsubscribe(shopId: number, ws: WebSocket): void {
    const room = this.rooms.get(shopId);
    if (!room) return;
    room.delete(ws);
    if (room.size === 0) this.rooms.delete(shopId);
  }

  /** Number of live consoles for a shop (handy for the POST response). */
  subscriberCount(shopId: number): number {
    return this.rooms.get(shopId)?.size ?? 0;
  }

  /** Fan a payload out to every live console for the shop. Best-effort. */
  broadcast(shopId: number, event: ScanConsoleEvent): number {
    const room = this.rooms.get(shopId);
    if (!room || room.size === 0) return 0;
    const data = JSON.stringify(event);
    let delivered = 0;
    for (const ws of room) {
      if (ws.readyState === WebSocket.OPEN) {
        ws.send(data);
        delivered += 1;
      }
    }
    return delivered;
  }
}

export const scanConsoleHub = new ScanConsoleHub();

// ── One-time connection tickets ──────────────────────────────────────────────
//
// The web console authenticates over the BFF (httpOnly cookies) and cannot put
// a bearer token on a browser WebSocket. So it first calls
// `POST /me/scan-console/ticket` (cookie-authed) to mint a short-lived,
// single-use ticket, then connects to `…/ws/scan-console?ticket=<t>`. The
// long-lived JWT never reaches browser JS.

type Ticket = { shopId: number; userId: number; expiresAt: number };

const TICKET_TTL_MS = 30_000;
const tickets = new Map<string, Ticket>();

export function issueScanTicket(shopId: number, userId: number, now: number): string {
  const token = randomBytes(24).toString('hex');
  tickets.set(token, { shopId, userId, expiresAt: now + TICKET_TTL_MS });
  // Opportunistic sweep so the map can't grow unbounded if tickets are minted
  // but never used (e.g. a console that requests then navigates away).
  if (tickets.size > 1_000) {
    for (const [t, entry] of tickets) {
      if (entry.expiresAt <= now) tickets.delete(t);
    }
  }
  return token;
}

/** Consume (single-use) and validate a ticket. Returns null if invalid/expired. */
function consumeScanTicket(token: string, now: number): Ticket | null {
  const entry = tickets.get(token);
  if (!entry) return null;
  tickets.delete(token);
  if (entry.expiresAt <= now) return null;
  return entry;
}

// ── WebSocket server (attached to the raw http.Server in server.ts) ──────────

const WS_PATH = '/ws/scan-console';

/**
 * Attach the scan-console WebSocket endpoint to the HTTP server. Uses
 * `noServer` mode so we own the upgrade handshake (auth + path check) before
 * promoting the socket.
 */
export function attachScanConsoleWs(server: HttpServer): void {
  const wss = new WebSocketServer({ noServer: true });

  server.on('upgrade', (req: IncomingMessage, socket: Duplex, head: Buffer) => {
    let pathname: string;
    let ticket: string | null;
    try {
      const url = new URL(req.url ?? '', 'http://localhost');
      pathname = url.pathname;
      ticket = url.searchParams.get('ticket');
    } catch {
      socket.destroy();
      return;
    }

    // Only our endpoint; ignore (and close) anything else upgrading.
    if (pathname !== WS_PATH) {
      socket.write('HTTP/1.1 404 Not Found\r\n\r\n');
      socket.destroy();
      return;
    }

    const entry = ticket ? consumeScanTicket(ticket, Date.now()) : null;
    if (!entry) {
      socket.write('HTTP/1.1 401 Unauthorized\r\n\r\n');
      socket.destroy();
      return;
    }

    wss.handleUpgrade(req, socket, head, (ws) => {
      const { shopId } = entry;
      scanConsoleHub.subscribe(shopId, ws);
      logger.info(
        { shopId, consoles: scanConsoleHub.subscriberCount(shopId) },
        'scan-console: console connected',
      );

      // Liveness: a dead/idle socket is reaped by the heartbeat below.
      (ws as WebSocket & { isAlive?: boolean }).isAlive = true;
      ws.on('pong', () => {
        (ws as WebSocket & { isAlive?: boolean }).isAlive = true;
      });

      ws.on('close', () => {
        scanConsoleHub.unsubscribe(shopId, ws);
      });
      ws.on('error', () => {
        scanConsoleHub.unsubscribe(shopId, ws);
      });

      const hello: ScanConsoleEvent = { type: 'connected', shopId };
      ws.send(JSON.stringify(hello));
    });
  });

  // Heartbeat: drop sockets that stopped answering pings (closed laptops,
  // dropped wifi) so rooms don't leak dead entries.
  const heartbeat = setInterval(() => {
    for (const ws of wss.clients) {
      const live = ws as WebSocket & { isAlive?: boolean };
      if (live.isAlive === false) {
        ws.terminate();
        continue;
      }
      live.isAlive = false;
      ws.ping();
    }
  }, 30_000);
  heartbeat.unref();

  wss.on('close', () => clearInterval(heartbeat));

  logger.info({ path: WS_PATH }, 'scan-console: websocket endpoint attached');
}

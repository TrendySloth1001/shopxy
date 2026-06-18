import { randomBytes } from 'node:crypto';
import type { Server as HttpServer, IncomingMessage } from 'node:http';
import type { Duplex } from 'node:stream';
import { WebSocketServer, WebSocket, type RawData } from 'ws';
import { productsService } from '../products/products.service.js';
import { logger } from '../../shared/logging/logger.js';

/**
 * Scan-console realtime backbone (PROTOTYPE).
 *
 * Both ends connect to ONE WebSocket room keyed by shopId:
 *   • the phone joins with role=scanner and pushes `{type:'scan', code}`
 *     messages; the backend resolves each code to a product and fans it out;
 *   • the web joins with role=console and renders the live list.
 *
 * Presence is broadcast on every join/leave so each end can show "connection
 * established · N watching". Scope is the shop: a scan reaches every console
 * subscribed to that shopId.
 *
 * PROTOTYPE LIMITS (single-instance only — see PENDING / production notes):
 *   • Rooms + tickets live in-process. Behind >1 node the fan-out won't reach
 *     sockets on another instance — swap this Map for a Redis pub/sub channel.
 *   • No scan history/replay: a console that connects after a scan misses it.
 */

export type ScanRole = 'scanner' | 'console';

// ── Realtime payloads (mirrored by the web client's zod schema) ───────────────

export type ScanItem = {
  /** Unique per scan event (not the product id) so the client can key a list. */
  scanId: string;
  productId: number;
  name: string;
  sku: string;
  barcode: string | null;
  /** Decimal serialised to a string. */
  sellingPrice: string;
  mrp: string | null;
  imageUrl: string | null;
  /** ISO timestamp the scan was received. */
  scannedAt: string;
  /** userId of the team member who scanned (shop-wide consoles show all). */
  scannedBy: number;
};

export type Presence = { consoles: number; scanners: number };

export type ScanConsoleEvent =
  | { type: 'connected'; shopId: number; role: ScanRole; presence: Presence }
  | { type: 'presence'; presence: Presence }
  | { type: 'scan'; scan: ScanItem }
  | { type: 'ack'; matched: boolean; code: string; name?: string; sku?: string }
  | { type: 'clear'; by: number };

type TaggedWs = WebSocket & { isAlive?: boolean; scanRole?: ScanRole; auth?: WsAuthCtx };

// ── Subscriber hub: shopId → set of live sockets (tagged by role) ─────────────

class ScanConsoleHub {
  private readonly rooms = new Map<number, Set<TaggedWs>>();

  subscribe(shopId: number, ws: TaggedWs, role: ScanRole): void {
    ws.scanRole = role;
    let room = this.rooms.get(shopId);
    if (!room) {
      room = new Set();
      this.rooms.set(shopId, room);
    }
    room.add(ws);
  }

  unsubscribe(shopId: number, ws: TaggedWs): void {
    const room = this.rooms.get(shopId);
    if (!room) return;
    room.delete(ws);
    if (room.size === 0) this.rooms.delete(shopId);
  }

  /** Live counts per role for a shop — drives the "N watching" presence line. */
  presence(shopId: number): Presence {
    const room = this.rooms.get(shopId);
    let consoles = 0;
    let scanners = 0;
    if (room) {
      for (const ws of room) {
        if (ws.scanRole === 'scanner') scanners += 1;
        else consoles += 1;
      }
    }
    return { consoles, scanners };
  }

  /**
   * Broadcast an arbitrary JSON event to every socket in a shop room. Lets other
   * features that share this socket (e.g. POS live cart) fan out without coupling
   * their event types here; clients ignore event `type`s they don't recognise.
   */
  publishRaw(shopId: number, event: Record<string, unknown>): number {
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

  /**
   * Fan a payload out to the shop's sockets. `role` limits delivery to one side
   * (e.g. scans only go to consoles); omit it to reach everyone. Best-effort.
   */
  broadcast(shopId: number, event: ScanConsoleEvent, opts?: { role?: ScanRole }): number {
    const room = this.rooms.get(shopId);
    if (!room || room.size === 0) return 0;
    const data = JSON.stringify(event);
    let delivered = 0;
    for (const ws of room) {
      if (opts?.role && ws.scanRole !== opts.role) continue;
      if (ws.readyState === WebSocket.OPEN) {
        ws.send(data);
        delivered += 1;
      }
    }
    return delivered;
  }
}

export const scanConsoleHub = new ScanConsoleHub();

// ── Resolve a scanned code → broadcastable scan item ─────────────────────────

/**
 * Look up a code (sku/barcode) in the shop and build the wire payload. Shared
 * by the REST endpoint and the WebSocket message handler. Returns null when no
 * product matches.
 */
export async function resolveScan(
  shopId: number,
  code: string,
  userId: number,
): Promise<ScanItem | null> {
  const product = await productsService.lookupProduct(shopId, code);
  if (!product) return null;
  return {
    scanId: randomBytes(8).toString('hex'),
    productId: product.id,
    name: product.name,
    sku: product.sku,
    barcode: product.barcode ?? null,
    sellingPrice: product.sellingPrice.toString(),
    mrp: product.mrp != null ? product.mrp.toString() : null,
    imageUrl: product.images[0]?.url ?? null,
    scannedAt: new Date().toISOString(),
    scannedBy: userId,
  };
}

// ── One-time connection tickets ──────────────────────────────────────────────
//
// A client authenticates over HTTP (Bearer on mobile, cookie BFF on web) to
// `POST /me/scan-console/ticket`, then opens the WebSocket with the ticket. The
// long-lived JWT never travels on the socket / reaches browser JS.

type Ticket = {
  shopId: number;
  userId: number;
  expiresAt: number;
  /// Shop role + granted permissions, carried so WS commands can gate the same
  /// way the REST mount's requireArea did (e.g. POS quick-add needs products:manage).
  shopRole?: string;
  permissions?: string[];
};

const TICKET_TTL_MS = 30_000;
const tickets = new Map<string, Ticket>();

export function issueScanTicket(
  shopId: number,
  userId: number,
  now: number,
  auth?: { shopRole?: string; permissions?: string[] },
): string {
  const token = randomBytes(24).toString('hex');
  tickets.set(token, {
    shopId,
    userId,
    expiresAt: now + TICKET_TTL_MS,
    shopRole: auth?.shopRole,
    permissions: auth?.permissions,
  });
  if (tickets.size > 1_000) {
    for (const [t, entry] of tickets) {
      if (entry.expiresAt <= now) tickets.delete(t);
    }
  }
  return token;
}

/// Identity + grants attached to a live socket, for WS command authorisation.
export interface WsAuthCtx {
  shopId: number;
  userId: number;
  shopRole?: string;
  permissions?: string[];
}

/// POS (and any future feature) registers a command handler invoked when a
/// socket sends `{ t: 'cmd', ... }`. Registration (rather than scan-console
/// importing POS) keeps the dependency one-way and avoids an import cycle.
type WsCommandHandler = (ws: WebSocket, ctx: WsAuthCtx, msg: Record<string, unknown>) => void;
let commandHandler: WsCommandHandler | null = null;
export function registerWsCommandHandler(fn: WsCommandHandler): void {
  commandHandler = fn;
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

export function attachScanConsoleWs(server: HttpServer): void {
  const wss = new WebSocketServer({ noServer: true });

  server.on('upgrade', (req: IncomingMessage, socket: Duplex, head: Buffer) => {
    let pathname: string;
    let ticket: string | null;
    let role: ScanRole;
    try {
      const url = new URL(req.url ?? '', 'http://localhost');
      pathname = url.pathname;
      ticket = url.searchParams.get('ticket');
      role = url.searchParams.get('role') === 'scanner' ? 'scanner' : 'console';
    } catch {
      socket.destroy();
      return;
    }

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

    wss.handleUpgrade(req, socket, head, (raw) => {
      const ws = raw as TaggedWs;
      const { shopId, userId } = entry;
      ws.auth = { shopId, userId, shopRole: entry.shopRole, permissions: entry.permissions };
      scanConsoleHub.subscribe(shopId, ws, role);
      const presence = scanConsoleHub.presence(shopId);
      logger.info({ shopId, role, ...presence }, 'scan-console: client connected');

      ws.isAlive = true;
      ws.on('pong', () => {
        ws.isAlive = true;
      });

      // A scanner pushes codes over the socket; resolve + fan out to consoles,
      // and ack back so the phone can confirm each scan reached the server.
      ws.on('message', (data: RawData) => {
        let msg: unknown;
        try {
          msg = JSON.parse(data.toString());
        } catch {
          return;
        }
        if (typeof msg !== 'object' || msg === null) return;
        const m = msg as Record<string, unknown>;

        // POS (and future features) command channel: `{ t:'cmd', reqId, op, … }`.
        if (m.t === 'cmd') {
          if (ws.auth && commandHandler) commandHandler(ws, ws.auth, m);
          return;
        }

        // scan-console scanner pushes: `{ type:'scan', code }`.
        if (ws.scanRole !== 'scanner' || m.type !== 'scan') return;
        const code = m.code;
        if (typeof code !== 'string' || code.trim() === '') return;

        void resolveScan(shopId, code.trim(), userId)
          .then((scan) => {
            if (scan) {
              scanConsoleHub.broadcast(shopId, { type: 'scan', scan }, { role: 'console' });
              sendEvent(ws, {
                type: 'ack',
                matched: true,
                code: code.trim(),
                name: scan.name,
                sku: scan.sku,
              });
            } else {
              sendEvent(ws, { type: 'ack', matched: false, code: code.trim() });
            }
          })
          .catch((err) => {
            logger.warn({ err, shopId }, 'scan-console: resolve failed');
            sendEvent(ws, { type: 'ack', matched: false, code: code.trim() });
          });
      });

      const cleanup = () => {
        scanConsoleHub.unsubscribe(shopId, ws);
        // Tell the rest of the room someone left so presence updates live.
        scanConsoleHub.broadcast(shopId, {
          type: 'presence',
          presence: scanConsoleHub.presence(shopId),
        });
      };
      ws.on('close', cleanup);
      ws.on('error', cleanup);

      // Greet the new socket, then tell the whole room the new presence.
      sendEvent(ws, { type: 'connected', shopId, role, presence });
      scanConsoleHub.broadcast(shopId, {
        type: 'presence',
        presence: scanConsoleHub.presence(shopId),
      });
    });
  });

  const heartbeat = setInterval(() => {
    for (const client of wss.clients) {
      const ws = client as TaggedWs;
      if (ws.isAlive === false) {
        ws.terminate();
        continue;
      }
      ws.isAlive = false;
      ws.ping();
    }
  }, 30_000);
  heartbeat.unref();
  wss.on('close', () => clearInterval(heartbeat));

  logger.info({ path: WS_PATH }, 'scan-console: websocket endpoint attached');
}

function sendEvent(ws: WebSocket, event: ScanConsoleEvent): void {
  if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(event));
}

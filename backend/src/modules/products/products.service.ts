import { Prisma, type TaxRateSource } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import { ledgerService } from '../ledger/ledger.service.js';
import { embeddingService } from '../search/embedding.service.js';
import { hsnService } from '../hsn/hsn.service.js';
import { HttpError } from '../../shared/http/errorHandler.js';

/// Payload slice that carries a GST slab — the product itself and each of its
/// variants have the same fields, so one helper covers both.
type RateBearing = {
  hsnCode?: string | null;
  taxPercent?: number;
  cessRate?: number;
  sellingPrice?: number;
  /// Set by [applyHsnRates]; never accepted from a client. Provenance is
  /// something the server observes, not something a caller may assert.
  taxSource?: TaxRateSource;
  hsnRevision?: string | null;
};

/// The HSN master, not the merchant's typing, decides the slab.
///
/// The product editors fill the rate the moment a code is picked, so in
/// practice the payload already agrees with the master. This is the server-side
/// backstop for everything that isn't the editor — a CSV import, a script, an
/// older app build, a direct API call — where naming a code but omitting the
/// rate used to silently create a product that bills at 0% under a heading that
/// says 18%.
///
/// **Price-aware.** Apparel and footwear are 5% up to ₹2,500 a piece and 18%
/// above, so the resolver is handed the selling price and decides. That's
/// arithmetic against data we hold, not a judgement call, and asking a merchant
/// to work it out is how you end up with a catalogue billing at one rate for
/// products that straddle the threshold.
///
/// **Only fills what's missing.** An explicitly-sent rate is left alone: nil
/// exceptions and advance rulings are real. But it's still recorded — a rate we
/// didn't derive is stamped `MANUAL`, so "which products bill at a rate their
/// code doesn't support" stays a query rather than a discovery.
///
/// Mutates in place, so call it BEFORE the payload is destructured — a `rest`
/// spread copies the fields and later mutation would be silently lost.
async function applyHsnRates(
  shopId: number,
  data: RateBearing & { variants?: RateBearing[] },
  /// The persisted selling price, for a PATCH that changes the code but not
  /// the price. Without it a threshold rule would silently fall back to the
  /// unconditional rate — a ₹4,000 shirt would land on 5% instead of 18%.
  fallbackPrice?: number,
): Promise<void> {
  const targets = [data, ...(data.variants ?? [])];
  const codes = targets
    .map((t) => t.hsnCode)
    .filter((c): c is string => typeof c === 'string' && c.trim().length > 0);
  if (codes.length === 0) return;

  for (const target of targets) {
    if (!target.hsnCode?.trim()) continue;
    // Per-target resolve rather than a bulk map: the threshold rules depend on
    // the price, and a variant can legitimately sit either side of it while
    // sharing the parent's code.
    const hit = await hsnService.resolveRate({
      code: target.hsnCode,
      shopId,
      // Variants carry their own price; fall back to the product's, then to
      // the persisted one, so a variant that only overrides the code — or a
      // patch that only changes the code — still gets a decided rate.
      price: target.sellingPrice ?? data.sellingPrice ?? fallbackPrice,
    });
    if (!hit) continue;

    if (target.taxPercent === undefined) {
      target.taxPercent = hit.gstRate;
      target.taxSource = hit.source as TaxRateSource;
      target.hsnRevision = hit.revision;
    } else {
      // The caller asserted a rate. Record whether it agrees with the master:
      // a matching value is still derived-equivalent and worth stamping as
      // such, so only a genuine divergence reads as MANUAL.
      const agrees = Math.abs(target.taxPercent - hit.gstRate) < 0.005;
      target.taxSource = agrees ? (hit.source as TaxRateSource) : 'MANUAL';
      target.hsnRevision = agrees ? hit.revision : null;
    }
    if (target.cessRate === undefined && hit.cessRate > 0) target.cessRate = hit.cessRate;
  }
}

/// Strip the obvious script-injection vectors from TEXT block markdown
/// before it lands in the DB.
///
/// DEFENSE-IN-DEPTH ONLY — this is a regex blocklist, NOT a sanitizer, and
/// must not be relied on as the primary XSS control. The PRIMARY defence is
/// the customer client's WHITELIST markdown renderer, which never interprets
/// raw HTML: the stored markdown is rendered through a constrained AST, so a
/// `<script>` (or anything else) in the column renders as literal text, not
/// markup. This scrub exists so the DB column never *stores* an obvious live
/// payload (e.g. if a future surface ever switched to an HTML renderer, or a
/// row leaked into a non-whitelist context).
///
/// CAT-M4 — a regex blocklist cannot match a real HTML parser: HTML entity
/// encoding (`&#x6a;avascript:`), malformed/never-closed tags, CSS
/// `expression()`, and exotic SVG/MathML vectors can survive it. The correct
/// fix is to sanitize on write with a parser-based library (sanitize-html /
/// isomorphic-dompurify) or store a constrained AST. That requires adding a
/// backend dependency, so it is DEFERRED; until then we keep this hardened
/// blocklist as the second line behind the client whitelist renderer.
///
/// P-4 hardening: beyond quoted `on*=` handlers and a wider tag set, this
/// also strips UNQUOTED handlers (`onerror=alert(1)`), dangerous URI schemes
/// (`javascript:` / `data:` / `vbscript:`) — including ones split by HTML
/// entities or whitespace — HTML comments (which can smuggle conditional
/// payloads), and runs to a fixed point so nested/obfuscated forms like
/// `<scr<script>ipt>` can't survive a single pass.
const DANGEROUS_TAGS =
  /<\s*\/?\s*(script|iframe|object|embed|style|link|meta|base|form|svg|math|template|noscript|frame|frameset|applet)\b[^>]*>/gi;
const EVENT_HANDLERS = /\son\w+\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+)/gi;
// Match dangerous schemes even when the colon/letters are broken up by HTML
// entities or stray whitespace (e.g. `java&#115;cript:`, `j a v a script:`).
const DANGEROUS_URIS =
  /(?:j\s*a\s*v\s*a\s*s\s*c\s*r\s*i\s*p\s*t|v\s*b\s*s\s*c\s*r\s*i\s*p\s*t|d\s*a\s*t\s*a)\s*(?:&#x?[0-9a-f]+;?|\s)*:/gi;
const HTML_COMMENTS = /<!--[\s\S]*?-->/g;
// Decode the numeric/hex HTML entities most often used to smuggle a scheme
// or handler past a literal-string blocklist, so the passes above see the
// canonical form. Intentionally narrow (no named-entity table) — this is a
// pre-pass for the blocklist, not a general HTML decoder.
function decodeNumericEntities(input: string): string {
  return input
    .replace(/&#x([0-9a-f]+);?/gi, (_m, hex) => {
      const code = parseInt(hex, 16);
      return Number.isFinite(code) ? String.fromCodePoint(code) : _m;
    })
    .replace(/&#(\d+);?/g, (_m, dec) => {
      const code = parseInt(dec, 10);
      return Number.isFinite(code) ? String.fromCodePoint(code) : _m;
    });
}

function scrubMarkdown(input: string): string {
  let out = input;
  // Iterate so a single removal that reveals a new match (nesting) is
  // also caught. Bounded to avoid pathological input looping.
  for (let i = 0; i < 5; i++) {
    const next = decodeNumericEntities(out)
      .replace(HTML_COMMENTS, '')
      .replace(DANGEROUS_TAGS, '')
      .replace(EVENT_HANDLERS, '')
      .replace(DANGEROUS_URIS, '');
    if (next === out) break;
    out = next;
  }
  return out;
}

function sanitizeContentBlocks(blocks: unknown): unknown {
  if (!Array.isArray(blocks)) return blocks;
  return blocks.map((b) => {
    if (b && typeof b === 'object' && (b as { kind?: string }).kind === 'TEXT') {
      const cur = b as { kind: 'TEXT'; markdown: string };
      return {
        ...cur,
        markdown: scrubMarkdown(cur.markdown),
      };
    }
    return b;
  });
}

const productSelect = {
  id: true,
  name: true,
  description: true,
  sku: true,
  barcode: true,
  hsnCode: true,
  // CAT-C2 — surfaced on the PDP and required on labels/invoices for
  // imported goods.
  countryOfOrigin: true,
  mrp: true,
  sellingPrice: true,
  purchasePrice: true,
  taxPercent: true,
  cessRate: true,
  // Provenance: lets the editors open the GST field as a readout for a derived
  // rate and as an input for one that was typed by hand.
  taxSource: true,
  hsnRevision: true,
  stockQuantity: true,
  lowStockThreshold: true,
  unit: true,
  categoryId: true,
  shopId: true,
  isActive: true,
  isPublished: true,
  ratingAvg: true,
  ratingCount: true,
  tags: true,
  highlights: true,
  specs: true,
  offers: true,
  totalSold: true,
  // Phase B fields — merchant editor sets brand; soldLast30d and
  // systemTags are read-only from the editor's perspective (set by
  // scheduler / admin).
  brand: true,
  soldLast30d: true,
  systemTags: true,
  // Phase C — A+ content blocks edited by the merchant, rendered in
  // the customer PDP Details tab.
  contentBlocks: true,
  // Phase E — variant axes + variants list.
  variantAxes: true,
  variants: {
    orderBy: { sortOrder: 'asc' as const },
    select: {
      id: true,
      sku: true,
      barcode: true,
      attributes: true,
      mrp: true,
      sellingPrice: true,
      purchasePrice: true,
      // CAT-H1 — variant-level GST source. Null means "inherit the
      // product's hsnCode / taxPercent"; the invoice resolver applies
      // that fallback. Surfaced here so the merchant editor and any
      // line-pricing caller can see the variant's own slab.
      hsnCode: true,
      taxPercent: true,
      stockQuantity: true,
      imageUrls: true,
      isDefault: true,
      isActive: true,
      sortOrder: true,
    },
  },
  createdAt: true,
  updatedAt: true,
  category: true,
  images: { orderBy: { sortOrder: 'asc' as const } },
} satisfies Prisma.ProductSelect;

export class ProductsService {
  async createProduct(
    data: {
      name: string;
      description?: string;
      sku: string;
      barcode?: string;
      hsnCode?: string;
      countryOfOrigin?: string;
      brand?: string;
      mrp: number;
      sellingPrice: number;
      purchasePrice: number;
      taxPercent?: number;
      cessRate?: number;
      /// Written by [applyHsnRates], never accepted from a client — the
      /// controller's schema has no such keys, so zod strips them at the
      /// boundary. Provenance is something the server observes.
      taxSource?: TaxRateSource;
      hsnRevision?: string | null;
      stockQuantity?: number;
      lowStockThreshold?: number;
      unit?: string;
      categoryId?: number;
      imageUrls?: string[];
      tags?: string[];
      highlights?: string[];
      specs?: unknown;
      offers?: unknown;
      contentBlocks?: unknown;
      variantAxes?: unknown;
      variants?: Array<{
        sku: string;
        barcode?: string | null;
        attributes: Record<string, string>;
        mrp: number;
        sellingPrice: number;
        purchasePrice: number;
        // CAT-H1 — optional per-variant GST source; null/omitted inherits
        // the product's hsnCode / taxPercent at invoice time.
        hsnCode?: string | null;
        taxPercent?: number;
        stockQuantity?: number;
        imageUrls?: string[];
        isActive?: boolean;
        sortOrder?: number;
      }>;
    },
    options: { createdById?: number; shopId?: number } = {},
  ) {
    if (!options.shopId) {
      throw new Error('createProduct requires options.shopId');
    }
    const shopId = options.shopId;
    // Fill any GST slab the payload named an HSN code for but left blank.
    // Must run BEFORE the destructure below — `rest` copies the fields.
    await applyHsnRates(shopId, data);

    const {
      imageUrls,
      stockQuantity,
      specs,
      offers,
      contentBlocks,
      variantAxes,
      variants,
      ...rest
    } = data;
    // Create the product with stockQuantity = 0; the ledger post below is
    // what funds it. This keeps products.stockQuantity in sync with the
    // ledger from row one — no orphan stock without a cost basis.

    // CAT-C1 — variant stockQuantity is a DISPLAY-ONLY breakdown of the
    // ledgered product total (the single source of truth read by the cart
    // and order-confirm decrement). A variant must never advertise more
    // units than the product is actually funded for, or the PDP swatch would
    // show "in stock" for inventory that doesn't exist (oversell). We clamp
    // each variant's stock to the funded product total here at write time.
    // The product total at create is whatever the OPENING ledger post funds.
    const fundedTotal = stockQuantity && stockQuantity > 0 ? stockQuantity : 0;
    const needsOpening = stockQuantity != null && stockQuantity > 0;

    // CAT-M1 — the product row and its opening-balance ledger post must be
    // ONE atomic unit. The old code created the product (committed), then
    // posted the ledger separately, then tried a compensating delete on
    // failure — a crash (or a failed delete) in between left a published
    // product that customers could see with stockQuantity=0 but no funding,
    // or an orphan product with no opening ledger. We now wrap create +
    // OPENING post in a single `prisma.$transaction` (ledger.post accepts a
    // `tx`). The product is created UNPUBLISHED inside the tx and only
    // flipped to published once funding succeeds in the same tx, so the
    // window where a half-funded product is visible never exists. A funding
    // failure rolls back the whole product.
    const productId = await prisma.$transaction(async (tx) => {
      const createData: Prisma.ProductUncheckedCreateInput = {
        ...rest,
          // JSONB columns need explicit `as Prisma.InputJsonValue` casts;
          // pass through unchanged when omitted so the column stays NULL.
          specs: specs === undefined ? undefined : (specs as Prisma.InputJsonValue),
          offers: offers === undefined ? undefined : (offers as Prisma.InputJsonValue),
          contentBlocks: contentBlocks === undefined
            ? undefined
            : (sanitizeContentBlocks(contentBlocks) as Prisma.InputJsonValue),
          variantAxes: variantAxes === undefined
            ? undefined
            : (variantAxes as Prisma.InputJsonValue),
          shopId,
          // Default new products to published so they're immediately
          // visible on the customer side. Schema default is false (kept
          // that way for historical imports and bulk seeds); the merchant
          // editor has no draft/publish toggle yet, so leaving it false
          // here meant every freshly created product silently failed to
          // appear in the customer feed.
          //
          // CAT-M1 — when this product carries an opening balance, create it
          // UNPUBLISHED and flip it on only after the ledger post succeeds
          // below (same tx). Products with no opening balance are funded at
          // 0 from row one, so publishing them immediately is safe.
          isPublished: !needsOpening,
          stockQuantity: 0,
          images: imageUrls?.length
            ? { create: imageUrls.map((url, i) => ({ url, sortOrder: i })) }
            : undefined,
          // Phase E — variants. When the merchant supplied a variants
          // list we create those directly (and skip the default). When
          // they didn't, we create exactly one default variant that
          // inherits product-level pricing — every product has ≥1
          // variant so the customer client always has a variantId to
          // attach to add-to-cart.
          //
          // P-2: variant `stockQuantity` is DISPLAY-ONLY breakdown metadata.
          // The authoritative on-hand figure is the product-level total,
          // which is the only quantity funded through the inventory ledger
          // (OPENING / SALE / PURCHASE / ADJUSTMENT, with FIFO cost layers
          // and a SELECT…FOR UPDATE lock). Variant stock is written verbatim
          // from the payload, carries no cost basis, and must not be treated
          // as a competing source of truth — reconcile it against the
          // ledgered product total, never the reverse.
          variants: {
            create: (variants && variants.length > 0)
              ? variants.map((v, i) => ({
                  sku: v.sku,
                  barcode: v.barcode ?? null,
                  attributes: v.attributes as Prisma.InputJsonValue,
                  mrp: v.mrp,
                  sellingPrice: v.sellingPrice,
                  purchasePrice: v.purchasePrice,
                  // CAT-H1 — variant-level GST source. Null hsnCode/omitted
                  // taxPercent ⇒ inherit the product's slab at invoice time.
                  hsnCode: v.hsnCode ?? null,
                  ...(v.taxPercent !== undefined && { taxPercent: v.taxPercent }),
                  // CAT-C1 — clamp display stock to the funded product total.
                  stockQuantity: Math.min(v.stockQuantity ?? 0, fundedTotal),
                  imageUrls: v.imageUrls ?? [],
                  isActive: v.isActive ?? true,
                  sortOrder: v.sortOrder ?? i,
                  isDefault: i === 0,
                }))
              : [{
                  sku: `${data.sku}-DEFAULT`,
                  attributes: {},
                  mrp: data.mrp,
                  sellingPrice: data.sellingPrice,
                  purchasePrice: data.purchasePrice,
                  stockQuantity: 0,
                  isDefault: true,
                }],
          },
      };
      const created = await tx.product.create({
        data: createData,
        select: { id: true },
      });

      if (needsOpening) {
        const result = await ledgerService.post(
          {
            shopId,
            direction: 'IN',
            reasonCode: 'OPENING',
            sourceType: 'OPENING',
            sourceId: created.id,
            lines: [
              {
                productId: created.id,
                quantity: stockQuantity!,
                unitPrice: data.purchasePrice,
              },
            ],
            createdById: options.createdById,
            note: 'Opening balance on product create',
          },
          tx,
        );

        if ('error' in result) {
          // Throwing rolls back the whole transaction — the product row, its
          // variants, and any partial ledger writes all vanish. No orphan
          // product, no compensating delete to fail.
          throw new Error(`Failed to post opening balance: ${result.error}`);
        }

        // Phase E v1 — keep the default variant's stockQuantity in sync
        // with the product-level ledger total. The PDP swatch picker
        // reads variant stock for display; the ledger remains the
        // source of truth.
        await tx.productVariant.updateMany({
          where: { productId: created.id, isDefault: true },
          data: { stockQuantity: stockQuantity! },
        });

        // Funding succeeded — now safe to make the product visible.
        await tx.product.update({
          where: { id: created.id },
          data: { isPublished: true },
        });
      }

      return created.id;
    });

    // New product → kick off a semantic embedding so it's searchable
    // by intent the moment it appears. Run AFTER the tx commits so we
    // never embed a row that rolled back. Failures are swallowed inside
    // reembedProduct + the cron retries periodically.
    void embeddingService.reembedProduct(productId);

    // Re-read outside the tx so the response reflects the funded stock.
    return prisma.product.findUniqueOrThrow({
      where: { id: productId },
      select: productSelect,
    });
  }

  /// Lightweight catalogue search for the POS "add without a barcode" picker —
  /// active products matching name / sku / barcode, minimal projection, capped.
  async posSearch(shopId: number, term: string, limit = 15) {
    const t = term.trim();
    if (!t) return [];
    const rows = await prisma.product.findMany({
      where: {
        shopId,
        isActive: true,
        OR: [
          { name: { contains: t, mode: 'insensitive' } },
          { sku: { contains: t, mode: 'insensitive' } },
          { barcode: { contains: t, mode: 'insensitive' } },
        ],
      },
      orderBy: { name: 'asc' },
      take: Math.min(Math.max(limit, 1), 30),
      select: {
        id: true,
        name: true,
        sku: true,
        sellingPrice: true,
        mrp: true,
        stockQuantity: true,
        images: { orderBy: { sortOrder: 'asc' }, take: 1, select: { url: true } },
      },
    });
    // CAT-L3 — `sellingPrice`/`mrp` are emitted as JS numbers ONLY for the
    // POS "add without a barcode" picker's DISPLAY. This is the JSON read
    // boundary: these floats must NEVER be fed back into money arithmetic.
    // The till re-sources the authoritative Decimal price by productId at
    // `addProduct`/confirm time (pos.service.ts), so paise can't drift. If a
    // future caller needs to compute on these, re-read the Decimal — do not
    // multiply/add the numbers below.
    return rows.map((p) => ({
      id: p.id,
      name: p.name,
      sku: p.sku,
      sellingPrice: Number(p.sellingPrice),
      mrp: Number(p.mrp),
      stock: Number(p.stockQuantity),
      imageUrl: p.images[0]?.url ?? null,
    }));
  }

  async listProducts(options: {
    shopId: number;
    activeOnly: boolean;
    lowStock: boolean;
    outOfStock: boolean;
    categoryId?: number;
    search: string;
    sortBy: string;
    sortOrder: 'asc' | 'desc';
    page: number;
    limit: number;
    skip: number;
  }) {
    // EVERY product read filters by shopId — non-negotiable for multi-tenant
    // safety. Even a search/categoryId combo without this filter would let
    // an authenticated merchant browse competitors' catalogs.
    const where: Record<string, unknown> = { shopId: options.shopId };

    if (options.activeOnly) where.isActive = true;
    if (options.categoryId) where.categoryId = options.categoryId;
    if (options.search) {
      where.OR = [
        { name: { contains: options.search, mode: 'insensitive' } },
        { sku: { contains: options.search, mode: 'insensitive' } },
        { barcode: { contains: options.search, mode: 'insensitive' } },
      ];
    }

    // Out-of-stock is the simple case: stockQuantity = 0, no
    // column-to-column comparison needed. Wins on Low if both are
    // toggled (defensive — UI keeps them mutually exclusive).
    if (options.outOfStock) {
      where.isActive = true;
      where.stockQuantity = 0;

      const orderBy = { [options.sortBy]: options.sortOrder } as Record<
        string,
        'asc' | 'desc'
      >;
      const [products, total] = await Promise.all([
        prisma.product.findMany({
          where,
          orderBy,
          skip: options.skip,
          take: options.limit,
          select: productSelect,
        }),
        prisma.product.count({ where }),
      ]);
      const enriched = await this._enrichWithLastActivity(products);
      return { products: enriched, total };
    }

    if (options.lowStock) {
      // Column-to-column comparison (stock_quantity <= low_stock_threshold)
      // can't be expressed in Prisma's typed `where` builder, so we drop
      // to two parameterised raw queries — one for COUNT, one for the
      // page-of-ids — and then a third typed read to hydrate. This is
      // the indexed path: ~3 round-trips with O(rows-on-page) memory,
      // vs the previous implementation which pulled every active row
      // for the shop into Node memory before filtering.
      // CAT-M3 — the page-of-ids raw query MUST order by the same column the
      // caller requested, else page *membership* is chosen by updated_at while
      // the final hydrate re-sorts by (say) sellingPrice → "low stock by price
      // ascending" returns the most-recently-updated low-stock rows re-sorted
      // by price, not the globally cheapest. Map the validated camelCase
      // sortBy onto its snake_case column (whitelist — never interpolate the
      // raw value) and emit a matching ORDER BY. `id` is appended as a stable
      // tiebreaker so pagination is deterministic across pages.
      const SORT_COLUMN: Record<string, string> = {
        updatedAt: 'updated_at',
        createdAt: 'created_at',
        name: 'name',
        sellingPrice: 'selling_price',
      };
      const sortColumn = SORT_COLUMN[options.sortBy] ?? 'updated_at';
      const orderByRaw = Prisma.raw(
        `ORDER BY ${sortColumn} ${options.sortOrder === 'asc' ? 'ASC' : 'DESC'}, id ASC`,
      );
      const categoryClause = options.categoryId
        ? Prisma.sql`AND category_id = ${options.categoryId}`
        : Prisma.empty;
      // P-3: the low-stock raw path must honour the same name/sku/barcode
      // search the typed path applies, else "low stock + search" returns
      // unfiltered low-stock results. Parameterised ILIKE (case-insensitive,
      // matching the typed `mode:'insensitive'`); values are bound, not spliced.
      const searchClause = options.search
        ? Prisma.sql`AND (
            name ILIKE ${'%' + options.search + '%'}
            OR sku ILIKE ${'%' + options.search + '%'}
            OR barcode ILIKE ${'%' + options.search + '%'}
          )`
        : Prisma.empty;

      const [countRow, pageRows] = await Promise.all([
        prisma.$queryRaw<{ count: bigint }[]>`
          SELECT COUNT(*)::bigint AS count FROM products
           WHERE shop_id = ${options.shopId}
             AND is_active = true
             AND stock_quantity > 0
             AND stock_quantity <= low_stock_threshold
             ${categoryClause}
             ${searchClause}
        `,
        prisma.$queryRaw<{ id: number }[]>`
          SELECT id FROM products
           WHERE shop_id = ${options.shopId}
             AND is_active = true
             AND stock_quantity > 0
             AND stock_quantity <= low_stock_threshold
             ${categoryClause}
             ${searchClause}
           ${orderByRaw}
           LIMIT ${options.limit} OFFSET ${options.skip}
        `,
      ]);

      const total = Number(countRow[0]?.count ?? 0);
      const pageIds = pageRows.map((r) => r.id);
      if (pageIds.length === 0) return { products: [], total };

      // CAT-M3 — `WHERE id IN (...)` returns rows in arbitrary Postgres order;
      // re-applying the same `orderBy` here would be redundant work and, for a
      // tied sort key, could disagree with the page query's id tiebreaker.
      // Hydrate, then re-impose the exact order the page query produced.
      const hydrated = await prisma.product.findMany({
        where: { id: { in: pageIds } },
        select: productSelect,
      });
      const byId = new Map(hydrated.map((p) => [p.id, p]));
      const products = pageIds
        .map((pid) => byId.get(pid))
        .filter((p): p is NonNullable<typeof p> => p != null);

      const enriched = await this._enrichWithLastActivity(products);
      return { products: enriched, total };
    }

    const orderBy = { [options.sortBy]: options.sortOrder } as Record<string, 'asc' | 'desc'>;

    const [products, total] = await Promise.all([
      prisma.product.findMany({
        where,
        orderBy,
        skip: options.skip,
        take: options.limit,
        select: productSelect,
      }),
      prisma.product.count({ where }),
    ]);

    const enriched = await this._enrichWithLastActivity(products);
    return { products: enriched, total };
  }

  /**
   * Enrich a page of products with last STOCK_IN / STOCK_OUT timestamps and
   * the vendor of the most recent STOCK_IN (when one exists).
   *
   * Single window-function pass over the relevant slice of stock_transactions,
   * so this stays O(page) regardless of ledger size. `lastVendor` is suppressed
   * when both vendor_id and vendor_name come back null — those are free-text
   * suppliers from the legacy `supplier_name` column.
   */
  private async _enrichWithLastActivity<T extends { id: number }>(
    products: T[],
  ): Promise<Array<T & {
    lastStockInAt: Date | null;
    lastStockOutAt: Date | null;
    lastVendor: { id: number; name: string } | null;
  }>> {
    if (products.length === 0) {
      return products.map((p) => ({
        ...p,
        lastStockInAt: null,
        lastStockOutAt: null,
        lastVendor: null,
      }));
    }

    const ids = products.map((p) => p.id);
    const rows = await prisma.$queryRaw<
      Array<{
        product_id: number;
        type: string;
        vendor_id: number | null;
        vendor_name: string | null;
        created_at: Date;
      }>
    >`
      WITH ranked AS (
        SELECT
          st.product_id,
          st.type,
          st.vendor_id,
          st.created_at,
          v.name AS vendor_name,
          ROW_NUMBER() OVER (PARTITION BY st.product_id, st.type ORDER BY st.created_at DESC) AS rn
        FROM stock_transactions st
        LEFT JOIN vendors v ON v.id = st.vendor_id
        WHERE st.product_id = ANY(${ids}::int[])
          AND st.type IN ('STOCK_IN','STOCK_OUT')
      )
      SELECT product_id, type, vendor_id, vendor_name, created_at
      FROM ranked
      WHERE rn = 1
    `;

    // Bucket by productId, splitting last-IN vs last-OUT.
    const byProduct = new Map<
      number,
      {
        lastIn?: { vendorId: number | null; vendorName: string | null; at: Date };
        lastOut?: { at: Date };
      }
    >();
    for (const r of rows) {
      const bucket = byProduct.get(r.product_id) ?? {};
      if (r.type === 'STOCK_IN') {
        bucket.lastIn = {
          vendorId: r.vendor_id,
          vendorName: r.vendor_name,
          at: r.created_at,
        };
      } else if (r.type === 'STOCK_OUT') {
        bucket.lastOut = { at: r.created_at };
      }
      byProduct.set(r.product_id, bucket);
    }

    return products.map((p) => {
      const b = byProduct.get(p.id);
      const lastIn = b?.lastIn;
      const lastOut = b?.lastOut;
      const lastVendor =
        lastIn && lastIn.vendorId != null && lastIn.vendorName != null
          ? { id: lastIn.vendorId, name: lastIn.vendorName }
          : null;
      return {
        ...p,
        lastStockInAt: lastIn?.at ?? null,
        lastStockOutAt: lastOut?.at ?? null,
        lastVendor,
      };
    });
  }

  /// Barcode/SKU scan resolver for the POS and scan-console. CAT-H4 — by
  /// default this EXCLUDES only soft-deleted (isActive=false) products: a scan
  /// of an archived SKU used to hand the cashier a sellable line for a product
  /// the merchant had deactivated, which the ledger then rejects at OUT-time
  /// (confusing, and any ledger-bypassing path would oversell a dead SKU).
  /// NOTE: `isPublished` is marketplace (storefront) visibility, NOT a
  /// sellability gate — counter inventory is routinely unpublished, so POS must
  /// still ring it up. Pass `includeInactive` on a merchant path that wants to
  /// surface an archived SKU; the returned `isActive`/`isPublished` flags let a
  /// caller decide. Excluding unpublished here breaks every counter sale.
  lookupProduct(shopId: number, code: string, includeInactive = false) {
    return prisma.product.findFirst({
      where: {
        shopId,
        ...(includeInactive ? {} : { isActive: true }),
        OR: [{ barcode: code }, { sku: code }],
      },
      select: productSelect,
    });
  }

  getProductById(shopId: number, id: number) {
    return prisma.product.findFirst({
      where: { id, shopId },
      include: {
        category: true,
        images: { orderBy: { sortOrder: 'asc' } },
        // Variants were omitted here, so GET /products/:id returned
        // variants: [] and the merchant edit form's Variants section
        // started empty on reload. Mirror the list projection's variants.
        variants: {
          orderBy: { sortOrder: 'asc' },
          select: {
            id: true,
            sku: true,
            barcode: true,
            attributes: true,
            mrp: true,
            sellingPrice: true,
            purchasePrice: true,
            // CAT-H1 — mirror the list projection so the edit form round-trips
            // each variant's own GST slab (null hsnCode / 0% inherits product).
            hsnCode: true,
            taxPercent: true,
            stockQuantity: true,
            imageUrls: true,
            isDefault: true,
            isActive: true,
            sortOrder: true,
          },
        },
        stockTransactions: {
          orderBy: { createdAt: 'desc' },
          take: 30,
          include: { vendor: { select: { id: true, name: true } } },
        },
      },
    });
  }

  async updateProduct(
    shopId: number,
    id: number,
    data: {
      name?: string;
      description?: string | null;
      sku?: string;
      barcode?: string | null;
      hsnCode?: string | null;
      countryOfOrigin?: string | null;
      brand?: string | null;
      mrp?: number;
      sellingPrice?: number;
      purchasePrice?: number;
      taxPercent?: number;
      cessRate?: number;
      /// Server-set by [applyHsnRates]; see the note on createProduct.
      taxSource?: TaxRateSource;
      hsnRevision?: string | null;
      lowStockThreshold?: number;
      unit?: string;
      categoryId?: number | null;
      isActive?: boolean;
      isPublished?: boolean;
      tags?: string[];
      highlights?: string[];
      specs?: unknown | null;
      offers?: unknown | null;
      contentBlocks?: unknown | null;
      variantAxes?: unknown | null;
      variants?: Array<{
        id?: number;
        sku: string;
        barcode?: string | null;
        attributes: Record<string, string>;
        mrp: number;
        sellingPrice: number;
        purchasePrice: number;
        // CAT-H1 — optional per-variant GST source; null/omitted inherits
        // the product's hsnCode / taxPercent at invoice time.
        hsnCode?: string | null;
        taxPercent?: number;
        stockQuantity?: number;
        imageUrls?: string[];
        isActive?: boolean;
        sortOrder?: number;
      }>;
    },
  ) {
    // A patch that moves the product to a different HSN code without naming a
    // rate re-derives the slab from the master — "change the code, the tax
    // follows" is the whole point of having a master. A patch that names both
    // keeps the merchant's number, stamped MANUAL if it disagrees. Runs before
    // the destructure so `rest` picks up the filled values.
    if (data.hsnCode?.trim()) {
      // Threshold rules need a price. A patch that changes only the code has
      // none, so read the persisted one rather than resolving unconditionally.
      const priced =
        data.sellingPrice === undefined
          ? await prisma.product.findFirst({
              where: { id, shopId },
              select: { sellingPrice: true },
            })
          : null;
      await applyHsnRates(shopId, data, priced ? Number(priced.sellingPrice) : undefined);
    } else {
      await applyHsnRates(shopId, data);
    }

    // updateMany returns count instead of throwing on missing row; that
    // lets us distinguish "wrong shop" from "wrong id" cleanly without
    // a separate guard query. count=0 → either id doesn't exist OR
    // belongs to another shop. Either way: 404 from the controller.
    const { specs, offers, contentBlocks, variantAxes, variants, ...rest } = data;

    // CAT-C3 — Legal Metrology s.18/s.36: selling price can never exceed MRP.
    // The controller refine already rejects a patch that supplies BOTH and
    // violates it; here we also catch a partial patch (only one of the pair)
    // by resolving the effective values against the persisted, shop-scoped row.
    if (data.mrp !== undefined || data.sellingPrice !== undefined) {
      const current = await prisma.product.findFirst({
        where: { id, shopId },
        select: { mrp: true, sellingPrice: true },
      });
      if (!current) return null;
      const effectiveMrp = new Prisma.Decimal(data.mrp ?? current.mrp);
      const effectiveSelling = new Prisma.Decimal(
        data.sellingPrice ?? current.sellingPrice,
      );
      if (effectiveSelling.greaterThan(effectiveMrp)) {
        throw new HttpError(
          400,
          'SELLING_ABOVE_MRP',
          'Selling price cannot exceed MRP.',
        );
      }
    }

    // CAT-C3 — same invariant for every supplied variant row.
    if (variants !== undefined) {
      for (const v of variants) {
        if (new Prisma.Decimal(v.sellingPrice).greaterThan(new Prisma.Decimal(v.mrp))) {
          throw new HttpError(
            400,
            'SELLING_ABOVE_MRP',
            'Variant selling price cannot exceed its MRP.',
          );
        }
      }
    }

    const result = await prisma.product.updateMany({
      where: { id, shopId },
      data: {
        ...rest,
        specs: specs === undefined
          ? undefined
          : specs === null
            ? Prisma.JsonNull
            : (specs as Prisma.InputJsonValue),
        offers: offers === undefined
          ? undefined
          : offers === null
            ? Prisma.JsonNull
            : (offers as Prisma.InputJsonValue),
        contentBlocks: contentBlocks === undefined
          ? undefined
          : contentBlocks === null
            ? Prisma.JsonNull
            : (sanitizeContentBlocks(contentBlocks) as Prisma.InputJsonValue),
        variantAxes: variantAxes === undefined
          ? undefined
          : variantAxes === null
            ? Prisma.JsonNull
            : (variantAxes as Prisma.InputJsonValue),
      },
    });
    if (result.count === 0) return null;

    // Phase E — when the merchant ships a full variants array, replace
    // the product's variants in place. Diff-by-id keeps stable rows so
    // CartItem.variantId references survive an edit. Bare-minimum
    // implementation: existing variants not listed are soft-deleted
    // (isActive=false) so historical references don't break.
    //
    // P-2: variant `stockQuantity` here is display-only breakdown — see
    // the create path. The ledgered product total is authoritative; this
    // write does not (and must not) post to the inventory ledger.
    if (variants !== undefined) {
      // CAT-C1 — variant stockQuantity is a display-only breakdown of the
      // ledgered product total (the single source of truth used by the cart
      // and order-confirm decrement). This edit path never touches the
      // ledger, so it must never let a variant advertise more than the
      // product is funded for. Clamp every write to the persisted, ledgered
      // product total. (Stock changes go through the ledger, not here.)
      const fundedRow = await prisma.product.findFirst({
        where: { id, shopId },
        select: { stockQuantity: true },
      });
      const fundedTotal = Number(fundedRow?.stockQuantity ?? 0);
      const clampStock = (q?: number) => Math.min(q ?? 0, fundedTotal);

      const existing = await prisma.productVariant.findMany({
        where: { productId: id },
        select: { id: true },
      });
      const incomingIds = new Set(
        variants.filter((v) => v.id != null).map((v) => v.id!),
      );
      const toDeactivate = existing
        .filter((e) => !incomingIds.has(e.id))
        .map((e) => e.id);
      if (toDeactivate.length > 0) {
        await prisma.productVariant.updateMany({
          where: { id: { in: toDeactivate } },
          data: { isActive: false },
        });
      }
      for (let i = 0; i < variants.length; i++) {
        const v = variants[i];
        if (v.id) {
          // Scope the update to THIS product (proven shop-owned by the
          // outer product.updateMany). Without the productId predicate a
          // caller could PATCH their own product with another shop's
          // variant id and overwrite its price/stock/SKU (cross-tenant
          // IDOR). updateMany lets us detect & skip a foreign/unknown id
          // via count===0 instead of mutating it.
          const res = await prisma.productVariant.updateMany({
            where: { id: v.id, productId: id },
            data: {
              sku: v.sku,
              barcode: v.barcode ?? null,
              attributes: v.attributes as Prisma.InputJsonValue,
              mrp: v.mrp,
              sellingPrice: v.sellingPrice,
              purchasePrice: v.purchasePrice,
              // CAT-H1 — keep the variant's GST source in sync with the
              // edit form. hsnCode is always written (null ⇒ inherit);
              // taxPercent only when supplied so we don't clobber an
              // existing slab with the column default.
              hsnCode: v.hsnCode ?? null,
              ...(v.taxPercent !== undefined && { taxPercent: v.taxPercent }),
              stockQuantity: clampStock(v.stockQuantity),
              imageUrls: v.imageUrls ?? [],
              isActive: v.isActive ?? true,
              sortOrder: v.sortOrder ?? i,
            },
          });
          if (res.count === 0) {
            // Variant id doesn't belong to this product — ignore it
            // rather than touching a row in another shop.
            continue;
          }
        } else {
          await prisma.productVariant.create({
            data: {
              productId: id,
              sku: v.sku,
              barcode: v.barcode ?? null,
              attributes: v.attributes as Prisma.InputJsonValue,
              mrp: v.mrp,
              sellingPrice: v.sellingPrice,
              purchasePrice: v.purchasePrice,
              // CAT-H1 — null hsnCode ⇒ inherit the product's slab.
              hsnCode: v.hsnCode ?? null,
              ...(v.taxPercent !== undefined && { taxPercent: v.taxPercent }),
              stockQuantity: clampStock(v.stockQuantity),
              imageUrls: v.imageUrls ?? [],
              isActive: v.isActive ?? true,
              sortOrder: v.sortOrder ?? i,
              isDefault: false,
            },
          });
        }
      }
    }
    // Any edit that touches the embedding source (name / description /
    // tags / highlights / specs) invalidates the cached embedding.
    // Cheap inline re-embed runs in the background — failures are
    // swallowed inside reembedProduct + the cron retries.
    const embedSourceChanged =
      data.name !== undefined ||
      data.description !== undefined ||
      data.tags !== undefined ||
      data.highlights !== undefined ||
      data.specs !== undefined;
    if (embedSourceChanged) {
      await prisma.product.updateMany({
        where: { id, shopId },
        data: { embeddedAt: null },
      });
      void embeddingService.reembedProduct(id);
    }
    return prisma.product.findFirst({
      where: { id, shopId },
      select: productSelect,
    });
  }

  async setPublished(shopId: number, id: number, isPublished: boolean) {
    // P-6 / MOD-2: a product must carry an explicit tax rate before it can
    // go live, so a null `taxPercent` can never silently zero GST on a
    // customer order. (Unpublishing is always allowed.)
    if (isPublished) {
      const target = await prisma.product.findFirst({
        where: { id, shopId },
        select: {
          taxPercent: true,
          mrp: true,
          sellingPrice: true,
          variants: { select: { mrp: true, sellingPrice: true } },
        },
      });
      if (!target) return null;
      if (target.taxPercent === null || target.taxPercent === undefined) {
        throw new HttpError(
          400,
          'TAX_RATE_REQUIRED',
          'Set a GST tax rate on this product before publishing it.',
        );
      }
      // CAT-C3 — never let a product whose selling price exceeds its MRP go
      // live on the storefront (Legal Metrology s.18/s.36). Re-checked here
      // (not only at write time) so a row created before this guard, or via
      // any non-controller path, can't reach customers above MRP.
      if (
        new Prisma.Decimal(target.sellingPrice).greaterThan(
          new Prisma.Decimal(target.mrp),
        )
      ) {
        throw new HttpError(
          400,
          'SELLING_ABOVE_MRP',
          'Selling price cannot exceed MRP; fix it before publishing.',
        );
      }
      const offendingVariant = target.variants.find((v) =>
        new Prisma.Decimal(v.sellingPrice).greaterThan(new Prisma.Decimal(v.mrp)),
      );
      if (offendingVariant) {
        throw new HttpError(
          400,
          'SELLING_ABOVE_MRP',
          'A variant selling price exceeds its MRP; fix it before publishing.',
        );
      }
    }
    const result = await prisma.product.updateMany({
      where: { id, shopId },
      data: { isPublished },
    });
    if (result.count === 0) return null;
    return prisma.product.findFirst({
      where: { id, shopId },
      select: productSelect,
    });
  }

  async deleteProduct(shopId: number, id: number) {
    // Guard cross-tenant deletes by scoping the ownership check itself
    // to (id, shopId). A merchant probing another shop's ids gets 404.
    const owned = await prisma.product.findFirst({
      where: { id, shopId },
      select: { id: true },
    });
    if (!owned) return null;

    // Soft-delete if the product is referenced anywhere — invoices, challans,
    // stock ledger, or adjustment lines all need the row to stay around so
    // historical documents render correctly. Otherwise hard-delete.
    const [stockRefs, invoiceRefs, challanRefs, adjustmentRefs] = await Promise.all([
      prisma.stockTransaction.count({ where: { productId: id } }),
      prisma.invoiceItem.count({ where: { productId: id } }),
      prisma.challanItem.count({ where: { productId: id } }),
      prisma.stockAdjustmentItem.count({ where: { productId: id } }),
    ]);
    const referenced = stockRefs + invoiceRefs + challanRefs + adjustmentRefs > 0;
    if (referenced) {
      return prisma.product.update({
        where: { id },
        data: { isActive: false },
        select: productSelect,
      });
    }
    return prisma.product.delete({ where: { id } });
  }

  // ── Image management ──────────────────────────────────────────────

  /// Verify (productId, shopId) ownership in one query so the rest of
  /// image management can trust the productId. Returns null when the
  /// product doesn't exist *or* belongs to another shop — both 404 to
  /// avoid leaking which is which.
  private async _ownsProduct(shopId: number, productId: number): Promise<boolean> {
    const row = await prisma.product.findFirst({
      where: { id: productId, shopId },
      select: { id: true },
    });
    return row !== null;
  }

  async addImage(shopId: number, productId: number, url: string, sortOrder?: number) {
    if (!(await this._ownsProduct(shopId, productId))) return null;
    const maxOrder = await prisma.productImage.aggregate({
      where: { productId },
      _max: { sortOrder: true },
    });
    const order = sortOrder ?? (maxOrder._max.sortOrder ?? -1) + 1;
    return prisma.productImage.create({ data: { productId, url, sortOrder: order } });
  }

  async deleteImage(shopId: number, productId: number, imageId: number) {
    if (!(await this._ownsProduct(shopId, productId))) return { error: 'Image not found' as const };
    const image = await prisma.productImage.findFirst({ where: { id: imageId, productId } });
    if (!image) return { error: 'Image not found' as const };
    await prisma.productImage.delete({ where: { id: imageId } });
    return { ok: true };
  }

  async reorderImages(shopId: number, productId: number, orderedIds: number[]) {
    if (!(await this._ownsProduct(shopId, productId))) return null;
    await prisma.$transaction(
      orderedIds.map((id, i) =>
        prisma.productImage.updateMany({ where: { id, productId }, data: { sortOrder: i } }),
      ),
    );
    return prisma.productImage.findMany({ where: { productId }, orderBy: { sortOrder: 'asc' } });
  }

  /// Refresh the `soldLast30d` denorm on every product from the
  /// trailing-30-day window of CONFIRMED invoice items. Runs nightly
  /// from the scheduler; idempotent — safe to invoke on demand from a
  /// debug endpoint while developing. One UPDATE … FROM statement so it
  /// stays O(rows in window) regardless of catalogue size, and the
  /// zero-out branch resets products that fell out of the window since
  /// the last tick.
  ///
  /// CAT-M2 — this is a BY-DESIGN nightly platform-wide denorm refresh: the
  /// `soldLast30d` trending signal is global across all shops, so there is no
  /// tenant boundary to apply. The `(SELECT id FROM products)` self-join the
  /// old version carried was redundant; we now LEFT JOIN the `agg` CTE onto
  /// the products table directly. The `IS DISTINCT FROM` guard still limits
  /// the actual row WRITES to rows whose value changed, so the lock footprint
  /// is the changed set, not the whole table. If the catalogue grows large
  /// enough that the full-table scan contends with merchant edits during the
  /// run, batch by id range here — but that's a scale follow-up, not a bug.
  async refreshSoldLast30d(): Promise<{ updated: number }> {
    const result = await prisma.$executeRaw`
      WITH agg AS (
        SELECT ii.product_id,
               COALESCE(SUM(ii.quantity), 0)::int AS sold
          FROM invoice_items ii
          JOIN invoices i ON i.id = ii.invoice_id
         WHERE i.status = 'CONFIRMED'
           AND i.created_at >= NOW() - INTERVAL '30 days'
         GROUP BY ii.product_id
      )
      UPDATE products p
         SET sold_last_30d = COALESCE(agg.sold, 0)
        FROM products src
        LEFT JOIN agg ON agg.product_id = src.id
       WHERE p.id = src.id
         AND p.sold_last_30d IS DISTINCT FROM COALESCE(agg.sold, 0)
    `;
    return { updated: Number(result) };
  }
}

export const productsService = new ProductsService();

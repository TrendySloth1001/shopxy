-- HSN phase 2: navigation rows, machine-applicable rate rules, the merchant's
-- own shortcut list, explicit rate overrides, and provenance stamping.
--
-- Hand-written and applied with `prisma migrate resolve --applied` for the
-- same reason as the phase-1 migration: `prisma migrate dev` can't diff this
-- schema because of the products.search_vector generated column.

-- ── HsnCode: navigation rows + conditional rate rules ───────────────────────
-- is_ratable=false marks a row that exists only so the picker can show where a
-- code sits (chapter "62 — Articles of apparel, not knitted"). Resolution skips
-- these; matching one and billing at it would invent a slab that doesn't exist.
ALTER TABLE "hsn_codes" ADD COLUMN "is_ratable" BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE "hsn_codes" ADD COLUMN "rate_rule" JSONB;

-- Resolution only ever looks at ratable rows in force, so keep that the
-- indexed path rather than scanning the chapter/heading rows alongside them.
CREATE INDEX "hsn_codes_ratable_idx" ON "hsn_codes"("code") WHERE "is_ratable" AND "is_active";

-- ── Provenance ─────────────────────────────────────────────────────────────
CREATE TYPE "TaxRateSource" AS ENUM ('HSN', 'HSN_RULE', 'OVERRIDE', 'MANUAL');

-- Existing rows default to MANUAL because that is exactly what they are: a
-- rate someone keyed by hand next to an unrelated HSN box. Not a guess — the
-- old form had no other path.
ALTER TABLE "products" ADD COLUMN "tax_source" "TaxRateSource" NOT NULL DEFAULT 'MANUAL';
ALTER TABLE "products" ADD COLUMN "hsn_revision" TEXT;

-- Lines raised before the master existed keep NULL; nothing is backfilled,
-- because inventing a provenance for a historical document is worse than
-- admitting we don't know.
ALTER TABLE "invoice_items" ADD COLUMN "hsn_revision" TEXT;

-- Find every product whose rate diverges from what its code supports.
CREATE INDEX "products_tax_source_idx" ON "products"("shop_id", "tax_source");

-- ── The merchant's own shortcut list ───────────────────────────────────────
-- Classification only. Deliberately has no rate column: a saved rate could go
-- stale against a Council revision and no deployment could fix it, because it
-- would be the merchant's data.
CREATE TABLE "shop_hsn_shortcuts" (
    "id" SERIAL NOT NULL,
    "shop_id" INTEGER NOT NULL,
    "term" TEXT NOT NULL,
    "label" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "use_count" INTEGER NOT NULL DEFAULT 0,
    "last_used_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "shop_hsn_shortcuts_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "shop_hsn_shortcuts_shop_id_term_key" ON "shop_hsn_shortcuts"("shop_id", "term");
CREATE INDEX "shop_hsn_shortcuts_shop_id_use_count_idx" ON "shop_hsn_shortcuts"("shop_id", "use_count");

ALTER TABLE "shop_hsn_shortcuts" ADD CONSTRAINT "shop_hsn_shortcuts_shop_id_fkey" FOREIGN KEY ("shop_id") REFERENCES "shops"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- ── Explicit, reasoned rate overrides ──────────────────────────────────────
-- Kept apart from shortcuts on purpose: saving a shortcut is housekeeping,
-- overriding a rate is a tax position. `reason` is NOT NULL because an
-- override without a stated basis is indistinguishable from a typo.
CREATE TABLE "shop_hsn_overrides" (
    "id" SERIAL NOT NULL,
    "shop_id" INTEGER NOT NULL,
    "code" TEXT NOT NULL,
    "gst_rate" DECIMAL(5,2) NOT NULL,
    "cess_rate" DECIMAL(5,2) NOT NULL DEFAULT 0,
    "reason" TEXT NOT NULL,
    "effective_from" DATE NOT NULL,
    "effective_to" DATE,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_by_user_id" INTEGER,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "shop_hsn_overrides_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "shop_hsn_overrides_shop_id_code_effective_from_key" ON "shop_hsn_overrides"("shop_id", "code", "effective_from");
CREATE INDEX "shop_hsn_overrides_shop_id_code_is_active_idx" ON "shop_hsn_overrides"("shop_id", "code", "is_active");

ALTER TABLE "shop_hsn_overrides" ADD CONSTRAINT "shop_hsn_overrides_shop_id_fkey" FOREIGN KEY ("shop_id") REFERENCES "shops"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "shop_hsn_overrides" ADD CONSTRAINT "shop_hsn_overrides_created_by_user_id_fkey" FOREIGN KEY ("created_by_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- Per-shop customization of document-number series (prefix/suffix/separator/
-- padding/yearly-reset). No row for a (shop_id, series) pair = system
-- default (see DEFAULT_SCHEMES in shared/numbering/sequences.ts) — purely
-- additive, zero backfill, every existing shop is unaffected until they
-- explicitly save a custom scheme.
CREATE TABLE "numbering_schemes" (
    "id" SERIAL NOT NULL,
    "shop_id" INTEGER NOT NULL,
    "series" TEXT NOT NULL,
    "prefix" TEXT NOT NULL DEFAULT '',
    "suffix" TEXT NOT NULL DEFAULT '',
    "separator" TEXT NOT NULL DEFAULT '/',
    "padding" INTEGER NOT NULL DEFAULT 5,
    "reset_yearly" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "numbering_schemes_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "numbering_schemes_shop_id_series_key" ON "numbering_schemes"("shop_id", "series");

ALTER TABLE "numbering_schemes" ADD CONSTRAINT "numbering_schemes_shop_id_fkey" FOREIGN KEY ("shop_id") REFERENCES "shops"("id") ON DELETE CASCADE ON UPDATE CASCADE;

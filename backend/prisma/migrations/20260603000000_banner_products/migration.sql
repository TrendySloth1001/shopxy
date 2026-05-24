-- Per-slide curated product list with display-only percent-off.
-- See model BannerProduct in schema.prisma for the contract.
CREATE TABLE "banner_products" (
    "id" SERIAL PRIMARY KEY,
    "banner_id" INTEGER NOT NULL,
    "product_id" INTEGER NOT NULL,
    "position" INTEGER NOT NULL DEFAULT 0,
    "discount_pct" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "banner_products_banner_id_fkey"
        FOREIGN KEY ("banner_id") REFERENCES "banners"("id")
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "banner_products_product_id_fkey"
        FOREIGN KEY ("product_id") REFERENCES "products"("id")
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX "banner_products_banner_id_product_id_key"
    ON "banner_products"("banner_id", "product_id");
CREATE INDEX "banner_products_banner_id_position_idx"
    ON "banner_products"("banner_id", "position");
CREATE INDEX "banner_products_product_id_idx"
    ON "banner_products"("product_id");

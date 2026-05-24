-- Phase 9 — Paid promotions.
--
-- One row per promotion. Counters update on impression record:
--   * delivered_impressions  cumulative
--   * spend_paise            cumulative (= floor(impressions * cpm / 1000))
--   * spend_today_paise      reset to 0 when spend_today_date advances
--   * spend_today_date       Postgres DATE — used to detect day-boundary
--                            crossings without timestamp arithmetic
-- Auto-pause is driven by the same update path; an hourly sweep cron
-- verifies the daily-cap state in case a clock skew or restart caused
-- the inline check to miss a tick.

CREATE TABLE "promotions" (
    "id" SERIAL PRIMARY KEY,
    "shop_id" INTEGER NOT NULL,
    "product_id" INTEGER NOT NULL,
    "budget_paise" INTEGER NOT NULL,
    "daily_cap_paise" INTEGER NOT NULL,
    "cpm_paise" INTEGER NOT NULL,
    "start_at" TIMESTAMP(3) NOT NULL,
    "end_at" TIMESTAMP(3) NOT NULL,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "delivered_impressions" INTEGER NOT NULL DEFAULT 0,
    "spend_paise" INTEGER NOT NULL DEFAULT 0,
    "spend_today_paise" INTEGER NOT NULL DEFAULT 0,
    "spend_today_date" DATE,
    "paused_reason" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "promotions_shop_id_fkey"
        FOREIGN KEY ("shop_id") REFERENCES "shops"("id") ON DELETE CASCADE,
    CONSTRAINT "promotions_product_id_fkey"
        FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE,
    CONSTRAINT "promotions_budget_positive_chk"
        CHECK ("budget_paise" > 0),
    CONSTRAINT "promotions_cap_positive_chk"
        CHECK ("daily_cap_paise" > 0),
    CONSTRAINT "promotions_cpm_positive_chk"
        CHECK ("cpm_paise" > 0),
    CONSTRAINT "promotions_window_chk"
        CHECK ("end_at" > "start_at")
);

CREATE INDEX "promotions_shop_id_is_active_idx"
    ON "promotions"("shop_id", "is_active");
CREATE INDEX "promotions_product_id_idx"
    ON "promotions"("product_id");
CREATE INDEX "promotions_is_active_start_at_end_at_idx"
    ON "promotions"("is_active", "start_at", "end_at");

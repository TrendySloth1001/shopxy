-- The customizable-numbering feature (see src/shared/numbering/sequences.ts)
-- allocates document numbers from a NEW counter key namespace keyed by the
-- stable series name ("SALE_INVOICE-<fy>") instead of the legacy display
-- prefix ("INV-<fy>") the app used before that feature existed. Every shop
-- that had already issued invoices/challans/quotations has a legacy counter
-- sitting at the real running count, but no row yet under the new key — so
-- the first invoice created after this feature ships starts back at 00001
-- and immediately collides with the 89th (or whichever) real invoice that
-- already exists with that number, hard-failing invoice creation.
--
-- One-time backfill: seed each new series key from its legacy prefix key's
-- CURRENT value, for every shop and every financial year already seen.
-- ON CONFLICT DO NOTHING makes this safe to run against a shop that has
-- already (for whatever reason) allocated under the new key — never
-- overwrites a real in-progress count.
INSERT INTO "counters" ("shop_id", "key", "value")
SELECT "shop_id", 'SALE_INVOICE-' || substring("key" from 5), "value"
FROM "counters" WHERE "key" LIKE 'INV-%'
ON CONFLICT ("shop_id", "key") DO NOTHING;

INSERT INTO "counters" ("shop_id", "key", "value")
SELECT "shop_id", 'PURCHASE_INVOICE-' || substring("key" from 5), "value"
FROM "counters" WHERE "key" LIKE 'PUR-%'
ON CONFLICT ("shop_id", "key") DO NOTHING;

INSERT INTO "counters" ("shop_id", "key", "value")
SELECT "shop_id", 'ESTIMATE-' || substring("key" from 5), "value"
FROM "counters" WHERE "key" LIKE 'EST-%'
ON CONFLICT ("shop_id", "key") DO NOTHING;

INSERT INTO "counters" ("shop_id", "key", "value")
SELECT "shop_id", 'CREDIT_NOTE-' || substring("key" from 5), "value"
FROM "counters" WHERE "key" LIKE 'CRN-%'
ON CONFLICT ("shop_id", "key") DO NOTHING;

INSERT INTO "counters" ("shop_id", "key", "value")
SELECT "shop_id", 'DEBIT_NOTE-' || substring("key" from 5), "value"
FROM "counters" WHERE "key" LIKE 'DBN-%'
ON CONFLICT ("shop_id", "key") DO NOTHING;

INSERT INTO "counters" ("shop_id", "key", "value")
SELECT "shop_id", 'CHALLAN-' || substring("key" from 4), "value"
FROM "counters" WHERE "key" LIKE 'CH-%'
ON CONFLICT ("shop_id", "key") DO NOTHING;

INSERT INTO "counters" ("shop_id", "key", "value")
SELECT "shop_id", 'QUOTATION-' || substring("key" from 5), "value"
FROM "counters" WHERE "key" LIKE 'QUO-%'
ON CONFLICT ("shop_id", "key") DO NOTHING;

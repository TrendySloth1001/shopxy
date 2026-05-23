-- Counters: per-key monotonic sequence for invoice / challan numbers.
-- Replaces the race-prone `count()+1` pattern. Callers do a single UPSERT
-- (INSERT … ON CONFLICT DO UPDATE SET value = counters.value + 1 RETURNING value)
-- which is atomic at the row level.

CREATE TABLE "counters" (
    "key"   TEXT NOT NULL,
    "value" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "counters_pkey" PRIMARY KEY ("key")
);

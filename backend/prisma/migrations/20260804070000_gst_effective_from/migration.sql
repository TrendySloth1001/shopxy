-- GST effective date: merchants may pin the exact calendar date GST starts
-- applying to their SALE documents, instead of being gated by GSTIN
-- presence/registrationType alone. Null = ungated (unaffected legacy rows).
ALTER TABLE "users" ADD COLUMN "gst_effective_from" DATE;

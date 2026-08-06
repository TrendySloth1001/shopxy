-- Which preset PDF look-and-feel a shop's invoices/quotations/challans
-- render with. Purely additive with a non-null default matching today's
-- only layout ("classic"), so every existing shop is unaffected until it
-- explicitly picks a different template.
ALTER TABLE "shops" ADD COLUMN "pdf_template_id" TEXT NOT NULL DEFAULT 'classic';

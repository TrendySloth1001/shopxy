import { InvoiceEditor } from "@/features/invoices/invoice-editor";
import { SALE_DOC_TYPES } from "@/features/invoices/schema";

export default async function NewInvoicePage({
  searchParams,
}: {
  searchParams: Promise<{ doc?: string }>;
}) {
  const { doc } = await searchParams;
  const initialDocumentType =
    doc && (SALE_DOC_TYPES as readonly string[]).includes(doc) ? doc : undefined;
  return <InvoiceEditor initialDocumentType={initialDocumentType} />;
}

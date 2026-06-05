"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { BackLink } from "@/shared/ui/page-header";
import { InvoiceEditor } from "@/features/invoices/invoice-editor";
import { getInvoice } from "@/features/invoices/api";
import type { Invoice } from "@/features/invoices/schema";
import { FormSkeleton } from "@/shared/ui/skeleton";

export default function EditInvoicePage() {
  const params = useParams<{ id: string }>();
  const id = Number(params.id);
  const [invoice, setInvoice] = useState<Invoice | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    void (async () => {
      try {
        const inv = await getInvoice(id);
        if (active) setInvoice(inv);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : "Could not load the invoice.");
      }
    })();
    return () => {
      active = false;
    };
  }, [id]);

  if (error) {
    return (
      <div className="w-full px-lg py-xxl md:px-xxl">
        <BackLink href={`/dashboard/invoices/${id}`} label="Invoice" />
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      </div>
    );
  }
  if (!invoice) {
    return <FormSkeleton />;
  }
  if (invoice.status !== "DRAFT") {
    return (
      <div className="w-full px-lg py-xxl md:px-xxl">
        <BackLink href={`/dashboard/invoices/${id}`} label="Invoice" />
        <p className="mt-md rounded-md bg-accent-amber-soft px-md py-sm text-body-sm text-accent-amber">
          Only draft invoices can be edited. This invoice is {invoice.status.toLowerCase()}.
        </p>
      </div>
    );
  }
  return <InvoiceEditor existing={invoice} />;
}

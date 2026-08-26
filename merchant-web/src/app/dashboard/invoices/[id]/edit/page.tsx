"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { useTranslations } from "next-intl";
import { BackLink } from "@/shared/ui/page-header";
import { InvoiceEditor } from "@/features/invoices/invoice-editor";
import { getInvoice } from "@/features/invoices/api";
import type { Invoice } from "@/features/invoices/schema";
import { FormSkeleton } from "@/shared/ui/skeleton";

export default function EditInvoicePage() {
  const t = useTranslations("invoices");
  const params = useParams<{ id: string }>();
  const id = params.id;
  const [invoice, setInvoice] = useState<Invoice | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    void (async () => {
      try {
        const inv = await getInvoice(id);
        if (active) setInvoice(inv);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : t("detail.loadError"));
      }
    })();
    return () => {
      active = false;
    };
  }, [id, t]);

  if (error) {
    return (
      <div className="w-full px-lg py-xxl md:px-xxl">
        <BackLink href={`/dashboard/invoices/${id}`} label={t("edit.backOne")} />
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
        <BackLink href={`/dashboard/invoices/${id}`} label={t("edit.backOne")} />
        <p className="mt-md rounded-md bg-accent-amber-soft px-md py-sm text-body-sm text-accent-amber">
          {t("edit.onlyDraft", { status: statusWord(t, invoice.status) })}
        </p>
      </div>
    );
  }
  return <InvoiceEditor existing={invoice} />;
}

function statusWord(t: ReturnType<typeof useTranslations>, status: string): string {
  const key = {
    DRAFT: "status.draftLower",
    CONFIRMED: "status.confirmedLower",
    CANCELLED: "status.cancelledLower",
  }[status];
  return key ? t(key) : status.toLowerCase();
}

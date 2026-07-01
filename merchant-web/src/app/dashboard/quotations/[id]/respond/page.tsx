"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { useTranslations } from "next-intl";
import { BackLink } from "@/shared/ui/page-header";
import { QuotationEditor } from "@/features/quotations/quotation-editor";
import { getQuotation } from "@/features/quotations/api";
import type { Quotation } from "@/features/quotations/schema";
import { FormSkeleton } from "@/shared/ui/skeleton";

export default function RespondQuotationPage() {
  const t = useTranslations("quotations");
  const params = useParams<{ id: string }>();
  const id = Number(params.id);
  const [quote, setQuote] = useState<Quotation | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    void (async () => {
      try {
        const q = await getQuotation(id);
        if (active) setQuote(q);
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
        <BackLink href={`/dashboard/quotations/${id}`} label={t("respond.backLabel")} />
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      </div>
    );
  }
  if (!quote) {
    return <FormSkeleton />;
  }
  if (quote.status !== "REQUESTED") {
    return (
      <div className="w-full px-lg py-xxl md:px-xxl">
        <BackLink href={`/dashboard/quotations/${id}`} label={t("respond.backLabel")} />
        <p className="mt-md rounded-md bg-accent-amber-soft px-md py-sm text-body-sm text-accent-amber">
          {t("respond.onlyRequested")}
        </p>
      </div>
    );
  }
  return <QuotationEditor existing={quote} />;
}

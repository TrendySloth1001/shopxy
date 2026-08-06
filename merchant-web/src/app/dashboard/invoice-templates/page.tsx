"use client";

import { useEffect, useState } from "react";
import Image from "next/image";
import { useTranslations } from "next-intl";
import { LayoutGrid, CheckCircle2, Eye } from "@/shared/icons";
import { Banner } from "@/features/auth/components/banner";
import { useCanManage } from "@/features/auth/use-can";
import { getShop, updateShop } from "@/features/shop/api";
import { listPdfTemplates } from "@/features/pdf-templates/api";
import type { PdfTemplate } from "@/features/pdf-templates/schema";

export default function InvoiceTemplatesPage() {
  const t = useTranslations("pdfTemplates");
  const canEdit = useCanManage("invoices");
  const [templates, setTemplates] = useState<PdfTemplate[] | null>(null);
  const [selected, setSelected] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState<string | null>(null);
  const [nonce, setNonce] = useState(0);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const [list, shop] = await Promise.all([listPdfTemplates(), getShop()]);
        if (!active) return;
        setTemplates([...list].sort((a, b) => a.order - b.order));
        setSelected(shop.pdfTemplateId ?? "classic");
        setError(null);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : t("errors.load"));
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [nonce, t]);

  async function onSelect(id: string) {
    if (!canEdit || id === selected || saving) return;
    setSaving(id);
    setError(null);
    try {
      const shop = await updateShop({ pdfTemplateId: id });
      setSelected(shop.pdfTemplateId ?? id);
    } catch (e) {
      setError(e instanceof Error ? e.message : t("errors.save"));
    } finally {
      setSaving(null);
    }
  }

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <div className="flex items-center gap-md">
        <span className="flex size-10 shrink-0 items-center justify-center rounded-lg bg-brand-soft text-brand-strong">
          <LayoutGrid size={20} />
        </span>
        <div>
          <h1 className="text-headline-md text-ink">{t("title")}</h1>
          <p className="text-body-sm text-muted">{t("subtitle")}</p>
        </div>
      </div>

      {error ? (
        <div className="mt-lg flex max-w-content flex-col gap-sm">
          <Banner variant="error" message={error} />
          <button
            type="button"
            onClick={() => setNonce((n) => n + 1)}
            className="self-start text-label-md text-brand-strong transition-colors hover:underline"
          >
            {t("errors.retry")}
          </button>
        </div>
      ) : null}

      <div className="mt-xl grid grid-cols-1 gap-lg sm:grid-cols-2 xl:grid-cols-3">
        {loading || !templates
          ? null
          : templates.map((tpl) => {
              const isSelected = tpl.id === selected;
              const isSaving = saving === tpl.id;
              return (
                <div
                  key={tpl.id}
                  className={`overflow-hidden rounded-lg border transition-colors ${
                    isSelected ? "border-brand-strong" : "border-hairline"
                  }`}
                >
                  <button
                    type="button"
                    onClick={() => onSelect(tpl.id)}
                    disabled={!canEdit || isSaving}
                    className="block w-full text-left disabled:cursor-default"
                  >
                    <div className="relative bg-white">
                      <Image
                        src={`/template-thumbnails/${tpl.id}.png`}
                        alt={tpl.name}
                        width={480}
                        height={284}
                        unoptimized
                        className="aspect-[480/284] w-full object-cover object-top"
                      />
                      {isSelected ? (
                        <span className="absolute right-sm top-sm flex size-7 items-center justify-center rounded-full bg-brand-strong text-white shadow-sm">
                          <CheckCircle2 size={16} />
                        </span>
                      ) : null}
                    </div>
                    <div className="p-md">
                      <p className="text-body-md font-medium text-ink">{tpl.name}</p>
                      <p className="mt-xxs text-body-sm text-muted">{tpl.description}</p>
                    </div>
                  </button>
                  <div className="border-t border-hairline px-md py-sm">
                    <button
                      type="button"
                      onClick={() =>
                        window.open(`/api/pdf-templates/${tpl.id}/sample?kind=invoice`, "_blank", "noopener,noreferrer")
                      }
                      className="inline-flex h-9 items-center gap-xs rounded-button border border-hairline px-sm text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
                    >
                      <Eye size={14} />
                      {t("preview")}
                    </button>
                  </div>
                </div>
              );
            })}
      </div>
    </div>
  );
}

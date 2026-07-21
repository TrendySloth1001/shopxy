"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { useTranslations } from "next-intl";
import { AlertCircle, AlertTriangle, ArrowRight, Info, X, type LucideIcon } from "@/shared/icons";
import type { DashboardAlert } from "../stats";

type SevStyle = { icon: LucideIcon; iconClass: string };

const STYLE: Record<DashboardAlert["severity"], SevStyle> = {
  critical: { icon: AlertCircle, iconClass: "text-error" },
  warning: { icon: AlertTriangle, iconClass: "text-warning" },
  info: { icon: Info, iconClass: "text-brand-strong" },
};

// Per-alert call-to-action label keys (the message already carries the detail).
const CTA_KEY: Record<string, string> = {
  "low-stock": "alert.cta.reorder",
  "gst-due": "alert.cta.fileGst",
  "sales-drop": "alert.cta.viewReport",
  "till-open": "alert.cta.openTill",
};

const DISMISS_KEY = "sx_dashboard_alerts_dismissed";

function readDismissed(): Set<string> {
  if (typeof sessionStorage === "undefined") return new Set();
  try {
    return new Set(JSON.parse(sessionStorage.getItem(DISMISS_KEY) ?? "[]") as string[]);
  } catch {
    return new Set();
  }
}

/** Dismissible smart-alert notifications (session-scoped dismissal). */
export function Alerts({ alerts }: { alerts: DashboardAlert[] }) {
  const t = useTranslations("dashboard");
  const [dismissed, setDismissed] = useState<Set<string>>(readDismissed);
  const visible = useMemo(() => alerts.filter((a) => !dismissed.has(a.id)), [alerts, dismissed]);

  function dismiss(id: string) {
    setDismissed((prev) => {
      const next = new Set(prev).add(id);
      if (typeof sessionStorage !== "undefined") {
        sessionStorage.setItem(DISMISS_KEY, JSON.stringify([...next]));
      }
      return next;
    });
  }

  if (visible.length === 0) return null;

  return (
    <section aria-label={t("alert.title")} className="divide-y divide-hairline overflow-hidden rounded-lg border border-hairline bg-canvas shadow-snackbar">
      {visible.map((a) => {
        const s = STYLE[a.severity];
        const Icon = s.icon;
        const cta = CTA_KEY[a.id] ? t(CTA_KEY[a.id]) : t("view");
        return (
          <div
            key={a.id}
            role={a.severity === "critical" ? "alert" : "status"}
            className="flex items-center gap-md px-md py-sm"
          >
            <Icon size={18} className={`shrink-0 ${s.iconClass}`} aria-hidden="true" />
            <p className="min-w-0 flex-1 text-body-md text-ink">{a.message}</p>
            <Link
              href={a.href}
              className="inline-flex h-8 shrink-0 items-center gap-xs rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
            >
              {cta}
              <ArrowRight size={14} aria-hidden="true" />
            </Link>
            <button
              type="button"
              onClick={() => dismiss(a.id)}
              aria-label={t("alert.dismiss")}
              className="flex size-8 shrink-0 items-center justify-center rounded-md text-subtle transition-colors hover:bg-surface-tint hover:text-ink focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
            >
              <X size={16} aria-hidden="true" />
            </button>
          </div>
        );
      })}
    </section>
  );
}

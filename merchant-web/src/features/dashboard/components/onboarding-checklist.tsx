import Link from "next/link";
import { useTranslations } from "next-intl";
import { ArrowRight, CheckCircle2, Circle } from "@/shared/icons";
import type { DashboardOnboarding } from "../stats";

/**
 * First-run setup checklist, shown in place of the KPI grid until the shop has
 * products and invoices. Action-focused (positive copy + a clear next step) so a
 * fresh shop sees guidance, not a wall of ₹0. `payoutsEnabled` comes from the
 * caller (the dashboard already loads payout status for its nudge).
 */
export function OnboardingChecklist({
  onboarding,
  payoutsEnabled,
}: {
  onboarding: DashboardOnboarding;
  payoutsEnabled: boolean;
}) {
  const t = useTranslations("dashboard");
  const steps = [
    {
      done: onboarding.totalProducts > 0,
      title: t("onboarding.product.title"),
      desc: t("onboarding.product.desc"),
      href: "/dashboard/products/new",
      cta: t("onboarding.product.cta"),
    },
    {
      done: onboarding.hasInvoices,
      title: t("onboarding.invoice.title"),
      desc: t("onboarding.invoice.desc"),
      href: "/dashboard/invoices/new",
      cta: t("onboarding.invoice.cta"),
    },
    {
      done: onboarding.hasParties,
      title: t("onboarding.customer.title"),
      desc: t("onboarding.customer.desc"),
      href: "/dashboard/parties",
      cta: t("onboarding.customer.cta"),
    },
    {
      done: payoutsEnabled,
      title: t("onboarding.payouts.title"),
      desc: t("onboarding.payouts.desc"),
      href: "/dashboard/payouts",
      cta: t("onboarding.payouts.cta"),
    },
  ];
  const completed = steps.filter((s) => s.done).length;

  return (
    <section aria-labelledby="setup-h" className="rounded-lg border border-hairline bg-canvas p-lg">
      <div className="flex flex-wrap items-end justify-between gap-md">
        <div>
          <h2 id="setup-h" className="text-headline-sm text-ink">
            {t("onboarding.heading")}
          </h2>
          <p className="mt-xs text-body-md text-muted">
            {t("onboarding.subtitle")}
          </p>
        </div>
        <p className="text-label-md tabular-nums text-muted" aria-label={t("onboarding.progressAria", { completed, total: steps.length })}>
          {t("onboarding.progress", { completed, total: steps.length })}
        </p>
      </div>

      <ul className="mt-lg divide-y divide-hairline">
        {steps.map((s) => (
          <li key={s.title} className="flex items-center gap-md py-md">
            {s.done ? (
              <CheckCircle2 size={20} className="shrink-0 text-success" aria-hidden="true" />
            ) : (
              <Circle size={20} className="shrink-0 text-subtle" aria-hidden="true" />
            )}
            <div className="min-w-0 flex-1">
              <p className={`text-body-md ${s.done ? "text-muted line-through" : "text-ink"}`}>{s.title}</p>
              {!s.done ? <p className="text-body-sm text-muted">{s.desc}</p> : null}
            </div>
            {!s.done ? (
              <Link
                href={s.href}
                className="inline-flex h-9 shrink-0 items-center gap-xs rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
              >
                {s.cta}
                <ArrowRight size={14} aria-hidden="true" />
              </Link>
            ) : null}
          </li>
        ))}
      </ul>
    </section>
  );
}

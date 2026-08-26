import Link from "next/link";
import { useTranslations } from "next-intl";
import {
  Boxes,
  CheckCircle2,
  ClipboardList,
  FileText,
  PackageX,
  RotateCcw,
  ShoppingBag,
  type LucideIcon,
} from "@/shared/icons";
import type { DashboardActionQueue } from "../stats";
import { Section } from "./ui";

type Tone = "brand" | "amber" | "error";

const TONE: Record<Tone, string> = {
  brand: "bg-brand-soft text-brand-strong",
  amber: "bg-accent-amber-soft text-accent-amber",
  error: "bg-error-soft text-error",
};

const ITEMS: Array<{
  key: keyof DashboardActionQueue;
  labelKey: string;
  href: string;
  Icon: LucideIcon;
  tone: Tone;
}> = [
  { key: "orders", labelKey: "action.ordersToConfirm", href: "/dashboard/orders", Icon: ShoppingBag, tone: "brand" },
  { key: "returns", labelKey: "action.returnsToReview", href: "/dashboard/returns", Icon: RotateCcw, tone: "amber" },
  { key: "quotations", labelKey: "action.quotesToPrice", href: "/dashboard/quotations", Icon: FileText, tone: "brand" },
  { key: "drafts", labelKey: "action.draftsToConfirm", href: "/dashboard/invoices", Icon: ClipboardList, tone: "brand" },
  { key: "outOfStock", labelKey: "action.outOfStock", href: "/dashboard/products", Icon: PackageX, tone: "error" },
  { key: "lowStock", labelKey: "action.lowStock", href: "/dashboard/products", Icon: Boxes, tone: "amber" },
];

export function ActionCenter({ queue }: { queue: DashboardActionQueue }) {
  const t = useTranslations("dashboard");
  const items = ITEMS.filter((it) => queue[it.key] > 0);

  return (
    <Section id="action-center" title={t("action.title")}>
      {items.length === 0 ? (
        <div className="flex items-center gap-md rounded-lg border border-hairline bg-canvas px-md py-lg text-muted">
          <CheckCircle2 size={20} className="text-success" aria-hidden="true" />
          <span className="text-body-md">{t("action.allCaughtUp")}</span>
        </div>
      ) : (
        <ul className="grid grid-cols-2 gap-md lg:grid-cols-3 xl:grid-cols-6">
          {items.map(({ key, labelKey, href, Icon, tone }) => {
            const label = t(labelKey);
            return (
              <li key={key}>
                <Link
                  href={href}
                  aria-label={`${queue[key]} ${label}`}
                  className="group flex items-center gap-md rounded-lg border border-hairline bg-canvas px-md py-md transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
                >
                  <span className={`flex size-9 shrink-0 items-center justify-center rounded-md ${TONE[tone]}`}>
                    <Icon size={18} aria-hidden="true" />
                  </span>
                  <span className="min-w-0">
                    <span className="block text-headline-sm tabular-nums text-ink">{queue[key]}</span>
                    <span className="block truncate text-body-sm text-muted">{label}</span>
                  </span>
                </Link>
              </li>
            );
          })}
        </ul>
      )}
    </Section>
  );
}

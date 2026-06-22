import Link from "next/link";
import {
  Boxes,
  CheckCircle2,
  ClipboardList,
  FileText,
  PackageX,
  RotateCcw,
  ShoppingBag,
  type LucideIcon,
} from "lucide-react";
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
  label: string;
  href: string;
  Icon: LucideIcon;
  tone: Tone;
}> = [
  { key: "orders", label: "Orders to confirm", href: "/dashboard/orders", Icon: ShoppingBag, tone: "brand" },
  { key: "returns", label: "Returns to review", href: "/dashboard/returns", Icon: RotateCcw, tone: "amber" },
  { key: "quotations", label: "Quotes to price", href: "/dashboard/quotations", Icon: FileText, tone: "brand" },
  { key: "drafts", label: "Drafts to confirm", href: "/dashboard/invoices", Icon: ClipboardList, tone: "brand" },
  { key: "outOfStock", label: "Out of stock", href: "/dashboard/products", Icon: PackageX, tone: "error" },
  { key: "lowStock", label: "Low stock", href: "/dashboard/products", Icon: Boxes, tone: "amber" },
];

/** Prioritised "needs attention" queue — one tile per non-empty counter. */
export function ActionCenter({ queue }: { queue: DashboardActionQueue }) {
  const items = ITEMS.filter((it) => queue[it.key] > 0);

  return (
    <Section id="action-center" title="Needs attention">
      {items.length === 0 ? (
        <div className="flex items-center gap-md rounded-lg border border-hairline bg-canvas px-md py-lg text-muted">
          <CheckCircle2 size={20} className="text-success" aria-hidden="true" />
          <span className="text-body-md">You’re all caught up — nothing needs action right now.</span>
        </div>
      ) : (
        <ul className="grid grid-cols-2 gap-md lg:grid-cols-3 xl:grid-cols-6">
          {items.map(({ key, label, href, Icon, tone }) => (
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
          ))}
        </ul>
      )}
    </Section>
  );
}

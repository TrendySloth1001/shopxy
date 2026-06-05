import Link from "next/link";
import { ArrowLeft, type LucideIcon } from "lucide-react";

/** Accent tones for the header icon puck — all from house colour tokens. */
const TONES = {
  brand: "bg-brand-soft text-brand-strong",
  flash: "bg-flash-deal-soft text-flash-deal",
  indigo: "bg-accent-indigo-soft text-accent-indigo",
  amber: "bg-accent-amber-soft text-accent-amber",
  teal: "bg-accent-teal-soft text-accent-teal",
} as const;

export type HeaderTone = keyof typeof TONES;

/**
 * Page header used across the dashboard sections: an accent icon puck, title +
 * subtitle, and an optional actions slot on the right. Keeps every screen's
 * masthead visually consistent.
 */
export function PageHeader({
  icon: Icon,
  title,
  subtitle,
  tone = "brand",
  children,
}: {
  icon: LucideIcon;
  title: string;
  subtitle?: string;
  tone?: HeaderTone;
  children?: React.ReactNode;
}) {
  return (
    <div className="flex flex-wrap items-start justify-between gap-md">
      <div className="flex items-start gap-md">
        <span className={`flex size-11 shrink-0 items-center justify-center rounded-lg ${TONES[tone]}`}>
          <Icon size={22} />
        </span>
        <div className="min-w-0">
          <h1 className="text-headline-md text-ink">{title}</h1>
          {subtitle ? <p className="mt-xs max-w-content text-body-md text-muted">{subtitle}</p> : null}
        </div>
      </div>
      {children ? <div className="flex shrink-0 items-center gap-sm">{children}</div> : null}
    </div>
  );
}

/** A back link to a parent route, used at the top of editor/detail pages. */
export function BackLink({ href, label }: { href: string; label: string }) {
  return (
    <Link
      href={href}
      className="inline-flex items-center gap-xs text-label-md text-muted transition-colors hover:text-ink"
    >
      <ArrowLeft size={16} /> {label}
    </Link>
  );
}

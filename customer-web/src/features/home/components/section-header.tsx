import Link from "next/link";
import { ArrowRight, ChevronRight } from "lucide-react";

/**
 * Section header shared by the feed blocks — port of the `_BlockHeader`
 * (pill "See all") and `HomeProductCarousel` (black circle) headers. Eyebrow in
 * brand caps over a bold title, with an optional see-all affordance on the right.
 */
export function SectionHeader({
  eyebrow,
  title,
  seeAllHref,
  variant = "pill",
}: {
  eyebrow?: string;
  title: string;
  seeAllHref?: string;
  variant?: "pill" | "circle";
}) {
  return (
    <div className="flex items-end justify-between gap-md px-lg">
      <div className="min-w-0">
        {eyebrow ? (
          <p className="mb-[2px] text-[10px] font-extrabold uppercase tracking-[1px] text-brand">{eyebrow}</p>
        ) : null}
        <h2 className="truncate text-[17px] font-extrabold text-ink">{title}</h2>
      </div>
      {seeAllHref ? (
        variant === "circle" ? (
          <Link
            href={seeAllHref}
            aria-label={`See all — ${title}`}
            className="flex size-8 shrink-0 items-center justify-center rounded-full bg-ink text-white transition-opacity hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            <ArrowRight size={18} aria-hidden />
          </Link>
        ) : (
          <Link
            href={seeAllHref}
            className="flex shrink-0 items-center gap-[2px] rounded-full bg-surface-tint px-[10px] py-[6px] text-[12px] font-bold text-ink transition-colors hover:bg-hairline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            See all <ChevronRight size={11} aria-hidden />
          </Link>
        )
      ) : null}
    </div>
  );
}

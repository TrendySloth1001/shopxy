import Link from "next/link";
import { ArrowRight, ChevronRight } from "lucide-react";

/**
 * Section header shared by the feed blocks — port of the `_BlockHeader`
 * (pill "See all") and `HomeProductCarousel` (black circle) headers.
 *
 * Layout: a 2px brand-green accent dot before the eyebrow, then the title at
 * text-title-md weight, "See all" aligned right as a pill or circle chip.
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
    <div className="flex items-center justify-between gap-md px-lg">
      {/* Title stack */}
      <div className="flex min-w-0 items-center gap-sm">
        {/* Accent dot motif — brand green, 6px, vertically centred */}
        <span
          className="hidden shrink-0 rounded-full bg-brand phone:block"
          style={{ width: 6, height: 6 }}
          aria-hidden
        />
        <div className="min-w-0">
          {eyebrow ? (
            <p className="mb-[1px] text-[10px] font-extrabold uppercase tracking-[1.2px] text-brand">
              {eyebrow}
            </p>
          ) : null}
          <h2 className="truncate text-title-md font-extrabold text-ink">{title}</h2>
        </div>
      </div>

      {/* See-all affordance */}
      {seeAllHref ? (
        variant === "circle" ? (
          <Link
            href={seeAllHref}
            aria-label={`See all — ${title}`}
            className="flex size-8 shrink-0 items-center justify-center rounded-full bg-ink text-white transition-all duration-200 hover:bg-brand hover:scale-105 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            <ArrowRight size={18} aria-hidden />
          </Link>
        ) : (
          <Link
            href={seeAllHref}
            className="flex shrink-0 items-center gap-[2px] rounded-full border border-hairline bg-white px-[10px] py-[6px] text-[12px] font-bold text-ink transition-all duration-200 hover:border-brand hover:text-brand focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            See all <ChevronRight size={11} aria-hidden />
          </Link>
        )
      ) : null}
    </div>
  );
}

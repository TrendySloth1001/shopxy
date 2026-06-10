import Link from "next/link";
import type { CategoryPuck } from "../types";
import { ImageBox } from "./image-box";

/** Category destination — the category listing page is future work (see PENDING). */
function categoryHref(p: CategoryPuck): string {
  return p.slug ? `/category/${p.slug}` : "/search";
}

/**
 * Circular category pucks — port of `home_category_pucks`. Horizontally
 * scrolling 64px circles with a label; falls back to the tint + first letter
 * when a category has no image.
 */
export function CategoryRail({ pucks }: { pucks: CategoryPuck[] }) {
  if (pucks.length === 0) return null;
  return (
    <nav
      aria-label="Categories"
      className="flex gap-lg overflow-x-auto bg-white px-lg py-md [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
    >
      {pucks.map((p) => (
        <Link
          key={p.categoryId}
          href={categoryHref(p)}
          className="flex w-16 shrink-0 flex-col items-center gap-[6px] focus-visible:outline-none"
        >
          <span
            className="flex size-16 items-center justify-center overflow-hidden rounded-full"
            style={{ backgroundColor: p.tint }}
          >
            {p.imageUrl ? (
              <ImageBox url={p.imageUrl} alt={p.label} placeholderColor={p.tint} />
            ) : (
              <span className="text-[22px] font-extrabold text-ink">{(p.label[0] ?? "?").toUpperCase()}</span>
            )}
          </span>
          <span className="line-clamp-1 max-w-full text-center text-[11px] text-ink">{p.label}</span>
        </Link>
      ))}
    </nav>
  );
}

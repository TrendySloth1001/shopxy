import { formatRelativeTime } from "@/shared/datetime";
import { Star } from "lucide-react";
import type { Review } from "../types";

interface Props {
  review: Review;
  /** Show a smaller layout for embedding inside the summary block */
  dense?: boolean;
}

export function ReviewTile({ review, dense = false }: Props) {
  const initial = (review.user.name || "?")[0].toUpperCase();
  return (
    <div className={dense ? "px-lg py-md" : "rounded-md border border-hairline bg-white p-md"}>
      {/* Author row */}
      <div className="flex items-center gap-sm">
        <span className="flex size-8 shrink-0 items-center justify-center rounded-full bg-brand-soft text-label-md font-extrabold text-brand-strong">
          {initial}
        </span>
        <div className="flex flex-col">
          <span className="text-body-sm font-bold text-ink">{review.user.name}</span>
          <span className="text-body-sm text-muted">
            {formatRelativeTime(review.createdAt)}
          </span>
        </div>
      </div>
      {/* Stars */}
      <div className="mt-sm flex items-center gap-xs">
        {[1, 2, 3, 4, 5].map((s) => (
          <Star
            key={s}
            size={13}
            aria-hidden
            className={s <= review.rating ? "fill-[#E05A2A] text-[#E05A2A]" : "fill-disabled text-disabled"}
          />
        ))}
      </div>
      {/* Title */}
      {review.title ? (
        <p className="mt-sm text-body-md font-bold text-ink">{review.title}</p>
      ) : null}
      {/* Body */}
      {review.body ? (
        <p className="mt-xs text-body-sm leading-relaxed text-muted">{review.body}</p>
      ) : null}
    </div>
  );
}

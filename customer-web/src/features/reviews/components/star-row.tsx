import { Star } from "lucide-react";

interface Props {
  rating: number;
  /** Icon size in px, default 16 */
  size?: number;
}

export function StarRow({ rating, size = 16 }: Props) {
  return (
    <span className="flex items-center" aria-label={`${rating.toFixed(1)} out of 5 stars`}>
      {[1, 2, 3, 4, 5].map((star) => {
        const filled = rating >= star;
        const half = !filled && rating >= star - 0.5;
        return (
          <span key={star} className="relative inline-block" style={{ width: size, height: size }}>
            <Star size={size} className="fill-disabled text-disabled" aria-hidden />
            {(filled || half) ? (
              <span
                className="absolute inset-0 overflow-hidden"
                style={{ width: half ? "50%" : "100%" }}
              >
                <Star size={size} className="fill-[#E05A2A] text-[#E05A2A]" aria-hidden />
              </span>
            ) : null}
          </span>
        );
      })}
    </span>
  );
}

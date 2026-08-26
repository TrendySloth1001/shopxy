"use client";

import { useEffect, useRef, useState, type ReactNode } from "react";

export function LazySection({
  children,
  placeholderClass = "h-40",
}: {
  children: ReactNode;
  placeholderClass?: string;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const [shown, setShown] = useState(false);

  useEffect(() => {
    if (shown) return;
    const el = ref.current;
    if (!el) return;
    const io = new IntersectionObserver(
      (entries) => {
        if (entries.some((e) => e.isIntersecting)) {
          setShown(true);
          io.disconnect();
        }
      },
      { rootMargin: "240px" },
    );
    io.observe(el);
    return () => io.disconnect();
  }, [shown]);

  return (
    <div ref={ref}>
      {shown ? children : <div className={`mt-md animate-pulse rounded-xs bg-hairline ${placeholderClass}`} />}
    </div>
  );
}

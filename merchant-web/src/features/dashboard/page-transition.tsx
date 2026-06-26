"use client";

import { useState, type ReactNode } from "react";
import { usePathname } from "next/navigation";

/**
 * Plays a "grab from the bottom" slide whenever the route changes: the new
 * page is a solid sheet that rises from below the fold to cover the outlet.
 * Keying on `pathname` remounts the frame on navigation so the slide replays;
 * clicking the already-active nav item keeps the same pathname, so nothing
 * moves. Reduced-motion is honoured globally (see `globals.css`).
 */
export function PageTransition({ children }: { children: ReactNode }) {
  const pathname = usePathname();
  return <SlideFrame key={pathname}>{children}</SlideFrame>;
}

function SlideFrame({ children }: { children: ReactNode }) {
  // Clip while the sheet slides up so it emerges from the bottom edge instead
  // of being visible mid-flight. Once settled, drop the clip so in-page sticky
  // headers and overlays (dropdowns, tooltips) aren't constrained by it.
  const [settled, setSettled] = useState(false);
  return (
    <div className={settled ? undefined : "overflow-hidden"}>
      <div
        className="sx-page-slide"
        onAnimationEnd={(e) => {
          if (e.animationName === "sx-page-in") setSettled(true);
        }}
      >
        {children}
      </div>
    </div>
  );
}

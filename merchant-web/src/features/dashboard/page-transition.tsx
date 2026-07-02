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
  // of being visible mid-flight. Once settled, drop BOTH the clip and the
  // animation class: `sx-page-slide` leaves a `transform: translateY(0)` (fill
  // `both`) plus `will-change: transform`, and either one establishes a
  // containing block for `position: fixed` descendants — which would anchor
  // in-page overlays (slide-over sheets, modals) to this box instead of the
  // viewport. translateY(0) is the identity transform, so dropping the class is
  // visually a no-op; it just frees fixed overlays to cover the full viewport.
  const [settled, setSettled] = useState(false);
  return (
    <div className={settled ? undefined : "overflow-hidden"}>
      <div
        className={settled ? undefined : "sx-page-slide"}
        onAnimationEnd={(e) => {
          if (e.animationName === "sx-page-in") setSettled(true);
        }}
      >
        {children}
      </div>
    </div>
  );
}

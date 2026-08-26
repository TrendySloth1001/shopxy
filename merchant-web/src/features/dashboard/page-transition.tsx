"use client";

import { useState, type ReactNode } from "react";
import { usePathname } from "next/navigation";

export function PageTransition({ children }: { children: ReactNode }) {
  const pathname = usePathname();
  return <SlideFrame key={pathname}>{children}</SlideFrame>;
}

function SlideFrame({ children }: { children: ReactNode }) {
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

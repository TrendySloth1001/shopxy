import type { ReactNode } from "react";

// Server-side title for this dashboard section (the pages are client components,
// which cannot export metadata themselves).
export const metadata = { title: "Shop" };

export default function SectionLayout({ children }: { children: ReactNode }) {
  return children;
}

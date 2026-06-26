"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { SECTIONS } from "./compliance-content";

const BASE = "/legal/compliance";

const ITEMS = [
  { href: BASE, label: "Overview" },
  ...SECTIONS.map((s) => ({ href: `${BASE}/${s.id}`, label: s.nav })),
];

/**
 * Docs sidebar. On large screens it's a sticky vertical list on the left; on
 * phones it collapses to a horizontally-scrolling chip row above the content.
 * The active topic is highlighted via the current pathname.
 */
export function ComplianceNav() {
  const pathname = usePathname();

  return (
    <nav aria-label="Compliance topics" className="flex flex-col gap-sm">
      <p className="hidden text-label-md uppercase tracking-wide text-subtle lg:block">
        On this site
      </p>
      <div className="-mx-lg flex gap-xs overflow-x-auto px-lg pb-sm lg:mx-0 lg:flex-col lg:gap-px lg:overflow-visible lg:px-0 lg:pb-0">
        {ITEMS.map((item) => {
          const active = pathname === item.href;
          return (
            <Link
              key={item.href}
              href={item.href}
              aria-current={active ? "page" : undefined}
              className={`shrink-0 py-xs text-body-md transition-colors lg:shrink ${
                active
                  ? "font-semibold text-ink"
                  : "text-muted hover:text-ink"
              }`}
            >
              {item.label}
            </Link>
          );
        })}
      </div>
    </nav>
  );
}

"use client";

import { useState } from "react";
import { ListTodo } from "@/shared/icons";
import type { SpecGroup } from "../types";

interface Props {
  groups: SpecGroup[];
}

export function PdpSpecs({ groups }: Props) {
  if (groups.length === 0) {
    return (
      <div className="flex flex-col items-center gap-sm px-lg py-xxl text-center">
        <ListTodo size={40} className="text-subtle" aria-hidden />
        <p className="text-body-md font-bold text-ink">No specifications yet</p>
        <p className="text-body-sm text-muted">The seller hasn&apos;t added a spec sheet for this product.</p>
      </div>
    );
  }

  // Collect unique tabs
  const tabs: string[] = [];
  const seen = new Set<string>();
  for (const g of groups) {
    if (g.tab && !seen.has(g.tab)) {
      seen.add(g.tab);
      tabs.push(g.tab);
    }
  }
  const hasTabs = tabs.length > 0;

  return hasTabs ? (
    <TabsSpecSheet groups={groups} tabs={tabs} />
  ) : (
    <FlatSpecSheet groups={groups} />
  );
}

function TabsSpecSheet({ groups, tabs }: { groups: SpecGroup[]; tabs: string[] }) {
  const [selectedTab, setSelectedTab] = useState(tabs[0] ?? "");
  const filtered = groups.filter((g) => g.tab === selectedTab);

  return (
    <div>
      <div className="flex gap-sm overflow-x-auto px-lg py-md scrollbar-none">
        {tabs.map((t) => {
          const isActive = t === selectedTab;
          return (
            <button
              key={t}
              onClick={() => setSelectedTab(t)}
              className={`shrink-0 rounded-button border px-md py-xs text-label-md font-bold transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand ${
                isActive
                  ? "border-brand bg-brand-soft text-brand-strong"
                  : "border-hairline bg-white text-ink hover:border-brand"
              }`}
            >
              {t}
            </button>
          );
        })}
      </div>
      <FlatSpecSheet groups={filtered} />
    </div>
  );
}

function FlatSpecSheet({ groups }: { groups: SpecGroup[] }) {
  return (
    <div className="flex flex-col gap-md px-lg pb-lg">
      {groups.map((group, gi) => (
        <div key={gi}>
          <p className="mb-sm text-label-md font-extrabold uppercase tracking-wide text-muted">
            {group.title}
          </p>
          <div className="overflow-hidden rounded-md border border-hairline bg-white">
            {group.rows.map((row, ri) => (
              <div key={ri}>
                {ri > 0 ? <div className="border-t border-hairline" /> : null}
                <div className="flex gap-md px-md py-sm">
                  <span className="w-[110px] shrink-0 text-body-sm font-semibold text-muted">
                    {row.label}
                  </span>
                  <span className="flex-1 text-body-sm font-semibold text-ink">{row.value}</span>
                </div>
              </div>
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}

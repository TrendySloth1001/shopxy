"use client";

import { useState } from "react";
import { History } from "lucide-react";
import { formatRelativeTime } from "@/shared/datetime";
import {
  fieldLabel,
  listContactChanges,
  type ContactChange,
} from "@/shared/contact-changes";

/**
 * Collapsible "Activity / history" panel for a party/vendor detail page.
 * Lazy-loads the field-level change log on first expand.
 */
export function ContactChangesSection({ kind, id }: { kind: "parties" | "vendors"; id: number }) {
  const [open, setOpen] = useState(false);
  const [rows, setRows] = useState<ContactChange[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  function expand() {
    const next = !open;
    setOpen(next);
    if (next && rows === null) {
      void listContactChanges(kind, id)
        .then(setRows)
        .catch((e) => setError(e instanceof Error ? e.message : "Could not load history."));
    }
  }

  return (
    <section className="py-xl">
      <button
        type="button"
        onClick={expand}
        aria-expanded={open}
        className="flex items-center gap-sm text-title-sm text-ink transition-colors hover:text-brand-strong"
      >
        <History size={18} className="text-muted" /> Activity & history
        <span className="text-body-sm text-subtle">{open ? "Hide" : "Show"}</span>
      </button>

      {open ? (
        <div className="mt-md">
          {error ? (
            <p className="text-body-sm text-error">{error}</p>
          ) : rows === null ? (
            <p className="text-body-sm text-subtle">Loading…</p>
          ) : rows.length === 0 ? (
            <p className="text-body-sm text-subtle">No changes recorded yet.</p>
          ) : (
            <ul className="border-t border-hairline">
              {rows.map((c) => (
                <li key={c.id} className="flex flex-wrap items-baseline gap-x-md gap-y-px border-b border-hairline py-sm">
                  <span className="text-body-md text-ink">{fieldLabel(c.field)}</span>
                  <span className="text-body-sm text-muted">
                    {c.oldValue ?? "—"} <span className="text-subtle">→</span> {c.newValue ?? "—"}
                  </span>
                  <span className="ml-auto text-label-md text-subtle">
                    {c.changedBy?.name ? `${c.changedBy.name} · ` : ""}
                    {formatRelativeTime(c.changedAt)}
                  </span>
                </li>
              ))}
            </ul>
          )}
        </div>
      ) : null}
    </section>
  );
}

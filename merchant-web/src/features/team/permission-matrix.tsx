"use client";

import {
  AREAS,
  AREA_LABELS,
  VIEW_ONLY,
  manageRight,
  viewRight,
} from "./permissions";

/**
 * Area × action grant grid. `manage` implies `view`; clearing `view` clears
 * `manage` too. The selected set is the source of truth (normalised by the
 * caller before sending).
 */
export function PermissionMatrix({
  value,
  onChange,
}: {
  value: Set<string>;
  onChange: (next: Set<string>) => void;
}) {
  function toggle(right: string, area: string, kind: "view" | "manage") {
    const next = new Set(value);
    const v = viewRight(area as never);
    const m = manageRight(area as never);
    if (next.has(right)) {
      next.delete(right);
      if (kind === "view") next.delete(m); // clearing view clears manage
    } else {
      next.add(right);
      if (kind === "manage") next.add(v); // manage implies view
    }
    onChange(next);
  }

  return (
    <div className="flex flex-col">
      <div className="flex items-center gap-md border-b border-hairline pb-xs">
        <span className="flex-1 text-label-md uppercase tracking-wide text-subtle">
          Area
        </span>
        <span className="w-14 text-center text-label-md uppercase tracking-wide text-subtle">
          View
        </span>
        <span className="w-14 text-center text-label-md uppercase tracking-wide text-subtle">
          Manage
        </span>
      </div>
      {AREAS.map((area) => {
        const v = viewRight(area);
        const m = manageRight(area);
        const viewOnly = VIEW_ONLY.has(area);
        return (
          <div key={area} className="flex items-center gap-md border-b border-hairline py-sm">
            <span className="flex-1 text-body-md text-ink">{AREA_LABELS[area]}</span>
            <span className="flex w-14 justify-center">
              <Check checked={value.has(v)} onChange={() => toggle(v, area, "view")} />
            </span>
            <span className="flex w-14 justify-center">
              {viewOnly ? (
                <span className="text-body-sm text-subtle">—</span>
              ) : (
                <Check checked={value.has(m)} onChange={() => toggle(m, area, "manage")} />
              )}
            </span>
          </div>
        );
      })}
    </div>
  );
}

function Check({
  checked,
  onChange,
}: {
  checked: boolean;
  onChange: () => void;
}) {
  return (
    <input
      type="checkbox"
      checked={checked}
      onChange={onChange}
      className="size-4 cursor-pointer accent-brand"
    />
  );
}

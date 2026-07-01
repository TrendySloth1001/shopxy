"use client";

import { useTranslations } from "next-intl";
import {
  AREAS,
  VIEW_ONLY,
  manageRight,
  viewRight,
  type Area,
} from "./permissions";

/**
 * Area × action grant grid. `manage` implies `view`; clearing `view` clears
 * `manage` too. The selected set is the source of truth (normalised by the
 * caller before sending).
 */
export function PermissionMatrix({
  value,
  onChange,
  ceiling,
}: {
  value: Set<string>;
  onChange: (next: Set<string>) => void;
  /**
   * The rights the current actor is allowed to grant (their own, normalised).
   * Rights outside it are disabled up front — the backend rejects
   * `CANNOT_GRANT_BEYOND_OWN_RIGHTS` anyway. `null`/undefined = owner (no limit).
   */
  ceiling?: Set<string> | null;
}) {
  const t = useTranslations("team");
  const canGrant = (right: string) => !ceiling || ceiling.has(right);

  function toggle(right: string, area: string, kind: "view" | "manage") {
    if (!canGrant(right)) return;
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
          {t("matrix.area")}
        </span>
        <span className="w-14 text-center text-label-md uppercase tracking-wide text-subtle">
          {t("matrix.view")}
        </span>
        <span className="w-14 text-center text-label-md uppercase tracking-wide text-subtle">
          {t("matrix.manage")}
        </span>
      </div>
      {AREAS.map((area) => {
        const v = viewRight(area);
        const m = manageRight(area);
        const viewOnly = VIEW_ONLY.has(area);
        return (
          <div key={area} className="flex items-center gap-md border-b border-hairline py-sm">
            <span className="flex-1">
              <span className="block text-body-md text-ink">
                {t(`area.${area}.label` as `area.${Area}.label`)}
              </span>
              <span className="block text-body-sm text-subtle">
                {t(`area.${area}.hint` as `area.${Area}.hint`)}
              </span>
            </span>
            <span className="flex w-14 justify-center">
              <Check
                checked={value.has(v)}
                disabled={!canGrant(v)}
                onChange={() => toggle(v, area, "view")}
              />
            </span>
            <span className="flex w-14 justify-center">
              {viewOnly ? (
                <span className="text-body-sm text-subtle">—</span>
              ) : (
                <Check
                  checked={value.has(m)}
                  disabled={!canGrant(m)}
                  onChange={() => toggle(m, area, "manage")}
                />
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
  disabled,
}: {
  checked: boolean;
  onChange: () => void;
  disabled?: boolean;
}) {
  const t = useTranslations("team");
  return (
    <input
      type="checkbox"
      checked={checked}
      disabled={disabled}
      onChange={onChange}
      title={disabled ? t("matrix.grantLocked") : undefined}
      className="size-4 cursor-pointer accent-brand disabled:cursor-not-allowed disabled:opacity-40"
    />
  );
}

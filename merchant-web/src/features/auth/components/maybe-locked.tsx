"use client";

import type { ReactNode } from "react";
import { Lock } from "lucide-react";
import { useAuth } from "../auth-context";
import { canManage, canView } from "../capabilities";
import type { Area } from "@/features/team/permissions";

/**
 * Gates a write action by permission — the web mirror of the Flutter app's
 * `MaybeLocked`. When the user may act, it renders the action untouched. When
 * they can't, it swaps in a greyed, non-interactive chip with a lock icon and
 * an "ask the owner" tooltip (instead of letting the click 403 on the backend).
 *
 * Used inside sections the user *can* view but not manage (e.g. a cashier with
 * `products:view` browsing Products): the list shows, the "New product" button
 * locks. Owners and members with `:manage` see the real action.
 */
export function MaybeLocked({
  area,
  action = "manage",
  label = "Locked",
  children,
}: {
  area: Area;
  /** Which right unlocks the action. Defaults to `manage` (write). */
  action?: "view" | "manage";
  /** Text shown on the locked chip in place of the action. */
  label?: string;
  children: ReactNode;
}) {
  const { user } = useAuth();
  const allowed = action === "view" ? canView(user, area) : canManage(user, area);
  if (allowed) return <>{children}</>;

  return (
    <span
      aria-disabled="true"
      title="You don’t have access. Ask the shop owner."
      className="inline-flex h-10 cursor-not-allowed items-center gap-xs rounded-button border border-hairline px-md text-label-md text-disabled"
    >
      <Lock size={14} className="shrink-0" />
      {label}
    </span>
  );
}

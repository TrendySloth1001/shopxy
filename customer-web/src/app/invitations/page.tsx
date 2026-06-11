"use client";

import { useState, useEffect, useCallback } from "react";
import Link from "next/link";
import { Mail } from "lucide-react";
import { AppHeader } from "@/features/auth/components/app-header";
import { RequireAuth } from "@/features/auth/components/require-auth";
import { InviteCard, InviteCardSkeleton } from "@/features/merchants/components/invite-card";
import {
  fetchIncomingInvitations,
  acceptInvitation,
  declineInvitation,
} from "@/features/merchants/api";
import type { Invitation } from "@/features/merchants/types";
import { useNotifications } from "@/features/notifications/notifications-context";

// ─── Types ──────────────────────────────────────────────────────────────────

type Tab = "pending" | "history";

// ─── Tab bar ────────────────────────────────────────────────────────────────

function TabBar({
  active,
  pendingCount,
  onChange,
}: {
  active: Tab;
  pendingCount: number;
  onChange: (t: Tab) => void;
}) {
  return (
    <div className="flex border-b border-hairline">
      {(["pending", "history"] as Tab[]).map((tab) => (
        <button
          key={tab}
          type="button"
          onClick={() => onChange(tab)}
          className={`flex-1 py-md text-label-lg font-bold capitalize transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand ${
            active === tab
              ? "border-b-2 border-brand text-brand"
              : "text-muted hover:text-ink"
          }`}
        >
          {tab === "pending"
            ? pendingCount > 0
              ? `Pending (${pendingCount})`
              : "Pending"
            : "History"}
        </button>
      ))}
    </div>
  );
}

// ─── Empty state ─────────────────────────────────────────────────────────────

function EmptyState({ tab }: { tab: Tab }) {
  return (
    <div className="flex flex-col items-center py-massive text-center">
      <div className="mb-lg flex h-24 w-24 items-center justify-center rounded-xl bg-hero-panel">
        <Mail size={40} className="text-muted" />
      </div>
      {tab === "pending" ? (
        <>
          <p className="text-title-sm font-extrabold text-ink">No pending invitations</p>
          <p className="mt-xs max-w-xs text-body-md text-muted">
            When a shop invites you to view their ledger, it will show up here.
          </p>
          <div className="mt-xl">
            <Link
              href="/merchants"
              className="inline-flex h-10 items-center rounded-button bg-brand px-xl text-label-lg font-extrabold text-white hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand transition-colors"
            >
              View my merchants
            </Link>
          </div>
        </>
      ) : (
        <>
          <p className="text-title-sm font-extrabold text-ink">No past invitations</p>
          <p className="mt-xs max-w-xs text-body-md text-muted">
            Accepted and declined invitations will appear here.
          </p>
        </>
      )}
    </div>
  );
}

// ─── Actionable invite row ────────────────────────────────────────────────────

function ActionableRow({
  invite,
  actionable,
  onMutated,
}: {
  invite: Invitation;
  actionable: boolean;
  onMutated: (updated: Invitation) => void;
}) {
  const [busy, setBusy] = useState(false);
  const [toast, setToast] = useState<{ msg: string; ok: boolean } | null>(null);
  const { refresh: refreshUnread } = useNotifications();

  const act = async (accept: boolean) => {
    if (busy) return;
    setBusy(true);
    try {
      const updated = accept
        ? await acceptInvitation(invite.id)
        : await declineInvitation(invite.id);
      onMutated(updated);
      setToast({
        msg: accept
          ? "Invitation accepted — you can now view this merchant."
          : "Invitation declined.",
        ok: true,
      });
      refreshUnread();
    } catch (e) {
      setToast({
        msg: e instanceof Error ? e.message : "Something went wrong.",
        ok: false,
      });
    } finally {
      setBusy(false);
    }
  };

  return (
    <div>
      <InviteCard
        invite={invite}
        actionable={actionable}
        busy={busy}
        onAccept={() => void act(true)}
        onDecline={() => void act(false)}
      />
      {toast && (
        <div
          className={`mt-sm rounded-sm px-md py-sm text-body-sm font-semibold ${
            toast.ok
              ? "bg-success-soft text-success"
              : "bg-error-soft text-error"
          }`}
        >
          {toast.msg}
        </div>
      )}
    </div>
  );
}

// ─── Main page content ────────────────────────────────────────────────────────

function InvitationsContent() {
  const [all, setAll] = useState<Invitation[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [tab, setTab] = useState<Tab>("pending");

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const page = await fetchIncomingInvitations({ status: "ALL", limit: 100 });
      setAll(page.data);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not load invitations.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    let cancelled = false;
    async function run() { await load(); }
    if (!cancelled) void run();
    return () => { cancelled = true; };
  }, [load]);

  const handleMutated = useCallback((updated: Invitation) => {
    setAll((prev) =>
      prev.map((inv) => (inv.id === updated.id ? updated : inv)),
    );
  }, []);

  const pending = all.filter((i) => i.status === "PENDING");
  const history = all.filter((i) => i.status !== "PENDING");
  const visible = tab === "pending" ? pending : history;

  // ── Error state ─────────────────────────────────────────────────────────
  if (error && all.length === 0) {
    return (
      <div className="mx-auto max-w-content px-lg py-massive text-center">
        <p className="text-title-sm font-bold text-ink mb-xs">Could not load invitations</p>
        <p className="text-body-sm text-muted mb-xl">{error}</p>
        <button
          onClick={() => void load()}
          className="inline-flex h-10 items-center rounded-button border border-hairline px-xl text-label-lg font-bold text-ink hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand transition-colors"
        >
          Try again
        </button>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-shell">
      {/* Tab bar */}
      <div className="sticky top-0 z-10 bg-canvas">
        <TabBar
          active={tab}
          pendingCount={pending.length}
          onChange={setTab}
        />
      </div>

      <div className="px-lg py-md">
        {/* Loading skeletons */}
        {loading && all.length === 0 ? (
          <div className="flex flex-col gap-md">
            {[0, 1, 2].map((i) => (
              <InviteCardSkeleton key={i} />
            ))}
          </div>
        ) : visible.length === 0 ? (
          <EmptyState tab={tab} />
        ) : (
          <div className="flex flex-col gap-md pb-lg">
            {visible.map((inv) => (
              <ActionableRow
                key={inv.id}
                invite={inv}
                actionable={tab === "pending"}
                onMutated={handleMutated}
              />
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

// ─── Page ────────────────────────────────────────────────────────────────────

export default function InvitationsPage() {
  return (
    <RequireAuth>
      <AppHeader />
      <main className="min-h-screen bg-canvas">
        <div className="mx-auto max-w-shell px-lg pt-xl pb-sm">
          <h1 className="text-headline-sm font-extrabold text-ink">Invitations</h1>
          <p className="mt-xs text-body-md text-muted">
            Shops that have invited you to view their ledger.
          </p>
        </div>
        <InvitationsContent />
      </main>
    </RequireAuth>
  );
}

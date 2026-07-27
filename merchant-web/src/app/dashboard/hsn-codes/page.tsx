"use client";

import { useCallback, useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { Percent, Plus, Star, Trash2, TriangleAlert } from "@/shared/icons";
import { Divider } from "@/shared/ui/divider";
import { PageHeader } from "@/shared/ui/page-header";
import { CardsSkeleton } from "@/shared/ui/skeleton";
import { useCanManage, useCanView } from "@/features/auth/use-can";
import { HsnField } from "@/features/products/components/hsn-field";
import {
  createOverride,
  deleteOverride,
  deleteShortcut,
  listOverrides,
  listShortcuts,
  saveShortcutOrThrow,
  type HsnOverride,
  type HsnResolution,
  type HsnShortcut,
} from "@/features/products/hsn";

/**
 * "My HSN codes" — the merchant's own view of the two things they can save
 * against the shared tariff.
 *
 * The product form asks *"save this as your code for X?"*, and until now that
 * was a one-way door: a saved shortcut silently won on every future product
 * with nowhere to see, correct, or remove it. This is that missing half.
 *
 * The two lists are deliberately not the same kind of thing, and the page is
 * built to keep them apart:
 *
 *  - **Saved codes** are classification only. They carry no rate — the live
 *    rate is joined on at read time — so they can never hold a merchant on a
 *    slab the Council has since changed. Low stakes, freely editable.
 *  - **Rate overrides** restate this shop's tax position on a code for the
 *    whole catalogue. They need `shop:manage`, demand a written reason, and
 *    delete softly, because they were the stated basis for invoices already
 *    raised.
 */
export default function HsnCodesPage() {
  const t = useTranslations("hsnCodes");
  const [shortcuts, setShortcuts] = useState<HsnShortcut[]>([]);
  const [overrides, setOverrides] = useState<HsnOverride[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [nonce, setNonce] = useState(0);

  const [repoint, setRepoint] = useState<HsnShortcut | null>(null);
  const [addingOverride, setAddingOverride] = useState(false);

  const canEditCodes = useCanManage("products");
  // Overrides sit behind the shop area, matching the backend guard — a Cashier
  // or Stockist can read the tariff and bill from it, but not move a rate.
  const canViewOverrides = useCanView("shop");
  const canEditOverrides = useCanManage("shop");

  const reload = useCallback(() => setNonce((n) => n + 1), []);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        // Overrides are fetched only when the role can see them; asking anyway
        // would 403 and turn a normal page into an error for a Cashier.
        const [s, o] = await Promise.all([
          listShortcuts(),
          canViewOverrides ? listOverrides() : Promise.resolve<HsnOverride[]>([]),
        ]);
        if (!active) return;
        setShortcuts(s);
        setOverrides(o);
        setError(null);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : t("errors.load"));
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [nonce, canViewOverrides, t]);

  /** Run a mutation, surface its message, and refresh on success. */
  async function run(fn: () => Promise<void>, fallbackKey: string) {
    setBusy(true);
    setActionError(null);
    try {
      await fn();
      reload();
      return true;
    } catch (e) {
      setActionError(e instanceof Error ? e.message : t(fallbackKey));
      return false;
    } finally {
      setBusy(false);
    }
  }

  const brokenCount = shortcuts.filter((s) => s.needsAttention).length;

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <PageHeader icon={Percent} title={t("title")} subtitle={t("subtitle")} />

      {actionError ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">
          {actionError}
        </p>
      ) : null}

      {loading ? (
        <CardsSkeleton count={3} />
      ) : error ? (
        <div className="flex flex-col items-start gap-md py-xxl">
          <p className="text-body-md text-muted">{error}</p>
          <button
            type="button"
            onClick={reload}
            className="inline-flex h-10 items-center rounded-button border border-hairline px-lg text-label-md text-ink transition-colors hover:bg-surface-tint"
          >
            {t("actions.tryAgain")}
          </button>
        </div>
      ) : (
        <>
          {/* ── Saved codes ─────────────────────────────────────────────── */}
          <section className="mt-xl">
            <h2 className="text-title-md text-ink">{t("saved.heading")}</h2>
            <p className="mt-xs max-w-content text-body-md text-muted">
              {t("saved.blurb")}
            </p>

            {brokenCount > 0 ? (
              <p className="mt-md inline-flex items-center gap-sm rounded-md bg-warning-soft px-md py-sm text-body-sm text-warning">
                <TriangleAlert size={16} />
                {t("saved.brokenBanner", { count: brokenCount })}
              </p>
            ) : null}

            {shortcuts.length === 0 ? (
              <p className="mt-md text-body-sm text-subtle">{t("saved.empty")}</p>
            ) : (
              <ul className="mt-md">
                {shortcuts.map((s) => (
                  <li
                    key={s.id}
                    className="flex flex-wrap items-center gap-md border-t border-hairline py-sm"
                  >
                    <div className="min-w-0 flex-1">
                      <p className="flex flex-wrap items-center gap-sm truncate text-body-md text-ink">
                        <Star size={14} className="shrink-0 text-brand" />
                        {s.label}
                        {s.needsAttention ? (
                          <span className="rounded-full bg-warning-soft px-sm py-px text-body-sm text-warning">
                            {t("saved.brokenBadge")}
                          </span>
                        ) : null}
                      </p>
                      <p className="truncate text-body-sm text-muted">
                        {/* The rate is joined live, never stored — so what shows
                            here is today's rate, not the one saved that day. */}
                        {s.code}
                        {s.name ? ` · ${s.name}` : ""}
                        {s.gstRate != null ? ` · ${s.gstRate}% GST` : ""}
                        {s.useCount > 0
                          ? ` · ${t("saved.usedCount", { count: s.useCount })}`
                          : ""}
                      </p>
                    </div>
                    <div className="flex shrink-0 items-center gap-xs">
                      <button
                        type="button"
                        onClick={() => setRepoint(s)}
                        disabled={busy || !canEditCodes}
                        title={canEditCodes ? undefined : t("lockedHint")}
                        className="inline-flex h-8 items-center rounded-button px-sm text-label-md text-muted transition-colors hover:bg-surface-tint hover:text-ink disabled:text-disabled disabled:hover:bg-transparent"
                      >
                        {t("actions.changeCode")}
                      </button>
                      <button
                        type="button"
                        onClick={() =>
                          void run(() => deleteShortcut(s.id), "errors.deleteShortcut")
                        }
                        disabled={busy || !canEditCodes}
                        aria-label={t("actions.removeSaved")}
                        title={canEditCodes ? undefined : t("lockedHint")}
                        className="rounded-md p-xs text-muted transition-colors hover:bg-error-soft hover:text-error disabled:text-disabled disabled:hover:bg-transparent"
                      >
                        <Trash2 size={16} />
                      </button>
                    </div>
                  </li>
                ))}
              </ul>
            )}
          </section>

          {/* ── Rate overrides ──────────────────────────────────────────── */}
          {canViewOverrides ? (
            <>
              <Divider className="my-xxl" />
              <section>
                <div className="flex flex-wrap items-start justify-between gap-md">
                  <div className="min-w-0">
                    <h2 className="text-title-md text-ink">{t("overrides.heading")}</h2>
                    <p className="mt-xs max-w-content text-body-md text-muted">
                      {t("overrides.blurb")}
                    </p>
                  </div>
                  <button
                    type="button"
                    onClick={() => setAddingOverride(true)}
                    disabled={busy || !canEditOverrides}
                    title={canEditOverrides ? undefined : t("overrides.lockedHint")}
                    className="inline-flex h-10 shrink-0 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:text-disabled disabled:hover:bg-transparent"
                  >
                    <Plus size={16} /> {t("overrides.add")}
                  </button>
                </div>

                {overrides.length === 0 ? (
                  <p className="mt-md text-body-sm text-subtle">{t("overrides.empty")}</p>
                ) : (
                  <ul className="mt-md">
                    {overrides.map((o) => (
                      <li
                        key={o.id}
                        className="flex flex-wrap items-start gap-md border-t border-hairline py-sm"
                      >
                        <div className="min-w-0 flex-1">
                          <p className="text-body-md text-ink">
                            {o.code} · {o.gstRate}%
                            {o.cessRate > 0
                              ? ` ${t("overrides.plusCess", { rate: o.cessRate })}`
                              : ""}
                          </p>
                          <p className="text-body-sm text-muted">{o.reason}</p>
                          <p className="text-body-sm text-subtle">
                            {t("overrides.effectiveFrom", {
                              date: formatDate(o.effectiveFrom),
                            })}
                          </p>
                        </div>
                        <button
                          type="button"
                          onClick={() =>
                            void run(() => deleteOverride(o.id), "errors.deleteOverride")
                          }
                          disabled={busy || !canEditOverrides}
                          aria-label={t("actions.removeOverride")}
                          title={canEditOverrides ? undefined : t("overrides.lockedHint")}
                          className="shrink-0 rounded-md p-xs text-muted transition-colors hover:bg-error-soft hover:text-error disabled:text-disabled disabled:hover:bg-transparent"
                        >
                          <Trash2 size={16} />
                        </button>
                      </li>
                    ))}
                  </ul>
                )}
              </section>
            </>
          ) : null}
        </>
      )}

      {repoint ? (
        <RepointDialog
          shortcut={repoint}
          busy={busy}
          onClose={() => setRepoint(null)}
          onSave={async (code) => {
            const ok = await run(
              () => saveShortcutOrThrow(repoint.label, code),
              "errors.saveShortcut",
            );
            if (ok) setRepoint(null);
          }}
        />
      ) : null}

      {addingOverride ? (
        <OverrideDialog
          busy={busy}
          onClose={() => setAddingOverride(false)}
          onSave={async (input) => {
            const ok = await run(() => createOverride(input), "errors.saveOverride");
            if (ok) setAddingOverride(false);
          }}
        />
      ) : null}
    </div>
  );
}

/** Server sends an ISO date; render it in the viewer's locale, date only. */
function formatDate(iso: string): string {
  const d = new Date(iso);
  return Number.isNaN(d.getTime()) ? iso : d.toLocaleDateString();
}

/**
 * Re-point a saved code at a different HSN.
 *
 * Saving is an upsert keyed on the merchant's own normalised wording, so
 * re-saving the same label moves the shortcut rather than duplicating it. This
 * is the only cure for `needsAttention` — a tariff revision retired the code
 * and the successor is a judgement call the merchant has to make, not one we
 * can infer for them.
 */
function RepointDialog({
  shortcut,
  busy,
  onClose,
  onSave,
}: {
  shortcut: HsnShortcut;
  busy: boolean;
  onClose: () => void;
  onSave: (code: string) => void;
}) {
  const t = useTranslations("hsnCodes");
  const [code, setCode] = useState(shortcut.code);
  const [resolved, setResolved] = useState<HsnResolution | null>(null);

  return (
    <ModalShell title={t("repoint.title", { label: shortcut.label })} onClose={onClose}>
      <p className="text-body-sm text-muted">{t("repoint.blurb")}</p>
      <HsnField
        label={t("repoint.codeLabel")}
        value={code}
        onChange={setCode}
        onResolved={setResolved}
        productName={shortcut.label}
      />
      <ModalActions
        busy={busy}
        // A code with no rate on file is exactly what got them here; saving
        // another one would just re-arm the same trap.
        disabled={!resolved}
        confirmLabel={t("repoint.confirm")}
        onCancel={onClose}
        onConfirm={() => resolved && onSave(resolved.requestedCode || code)}
      />
    </ModalShell>
  );
}

/**
 * Record a rate override.
 *
 * The platform rate for the chosen code is resolved and shown as the merchant
 * types, so the dialog states the departure plainly — "we say 5%, you are
 * saying 18%" — rather than letting a number be entered against nothing.
 */
function OverrideDialog({
  busy,
  onClose,
  onSave,
}: {
  busy: boolean;
  onClose: () => void;
  onSave: (input: { code: string; gstRate: number; reason: string }) => void;
}) {
  const t = useTranslations("hsnCodes");
  const [code, setCode] = useState("");
  const [resolved, setResolved] = useState<HsnResolution | null>(null);
  const [rate, setRate] = useState("");
  const [reason, setReason] = useState("");

  const parsedRate = Number(rate);
  const rateValid = rate.trim() !== "" && Number.isFinite(parsedRate) && parsedRate >= 0 && parsedRate <= 100;
  const diverges = rateValid && resolved != null && parsedRate !== resolved.gstRate;
  const ready = code.trim() !== "" && rateValid && reason.trim().length >= 3;

  return (
    <ModalShell title={t("overrides.dialogTitle")} onClose={onClose}>
      <p className="text-body-sm text-muted">{t("overrides.dialogBlurb")}</p>

      <HsnField
        label={t("overrides.codeLabel")}
        value={code}
        onChange={setCode}
        onResolved={setResolved}
        productName=""
      />

      {resolved ? (
        <p className="text-body-sm text-subtle">
          {t("overrides.platformRate", { code: resolved.code, rate: resolved.gstRate })}
        </p>
      ) : null}

      <label className="flex flex-col gap-xs">
        <span className="text-label-md text-muted">{t("overrides.rateLabel")}</span>
        <input
          value={rate}
          onChange={(e) => setRate(e.target.value)}
          inputMode="decimal"
          placeholder="18"
          className="h-10 rounded-input border border-hairline bg-field px-md text-body-md text-ink outline-none focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft"
        />
      </label>

      {diverges ? (
        <p className="rounded-md bg-warning-soft px-md py-sm text-body-sm text-warning">
          {t("overrides.diverges", {
            code: resolved!.code,
            platform: resolved!.gstRate,
            yours: parsedRate,
          })}
        </p>
      ) : null}

      <label className="flex flex-col gap-xs">
        <span className="text-label-md text-muted">{t("overrides.reasonLabel")}</span>
        <textarea
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          rows={3}
          placeholder={t("overrides.reasonPlaceholder")}
          className="rounded-input border border-hairline bg-field px-md py-sm text-body-md text-ink outline-none focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft"
        />
        <span className="text-body-sm text-subtle">{t("overrides.reasonHelper")}</span>
      </label>

      <ModalActions
        busy={busy}
        disabled={!ready}
        confirmLabel={t("overrides.confirm")}
        onCancel={onClose}
        onConfirm={() =>
          onSave({
            code: (resolved?.requestedCode ?? code).trim(),
            gstRate: parsedRate,
            reason: reason.trim(),
          })
        }
      />
    </ModalShell>
  );
}

function ModalShell({
  title,
  onClose,
  children,
}: {
  title: string;
  onClose: () => void;
  children: React.ReactNode;
}) {
  return (
    <div
      className="fixed inset-0 z-50 flex items-end justify-center overflow-y-auto bg-scrim/30 p-lg sm:items-center"
      onClick={onClose}
    >
      <div
        className="flex w-full max-w-form flex-col gap-md rounded-dialog bg-surface p-lg shadow-menu"
        onClick={(e) => e.stopPropagation()}
      >
        <h3 className="text-title-md text-ink">{title}</h3>
        {children}
      </div>
    </div>
  );
}

function ModalActions({
  busy,
  disabled,
  confirmLabel,
  onCancel,
  onConfirm,
}: {
  busy: boolean;
  disabled?: boolean;
  confirmLabel: string;
  onCancel: () => void;
  onConfirm: () => void;
}) {
  const t = useTranslations("hsnCodes");
  return (
    <div className="mt-sm flex justify-end gap-md">
      <button
        type="button"
        onClick={onCancel}
        disabled={busy}
        className="inline-flex h-10 items-center rounded-button px-md text-label-md text-muted transition-colors hover:text-ink disabled:text-disabled"
      >
        {t("actions.cancel")}
      </button>
      <button
        type="button"
        onClick={onConfirm}
        disabled={busy || disabled}
        className="inline-flex h-10 items-center rounded-button bg-brand px-lg text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:bg-disabled"
      >
        {busy ? t("actions.saving") : confirmLabel}
      </button>
    </div>
  );
}

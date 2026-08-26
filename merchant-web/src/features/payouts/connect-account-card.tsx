"use client";

import { useState } from "react";
import { Link2, CheckCircle2, Loader2 } from "@/shared/icons";
import { useTranslations } from "next-intl";
import { verifyConnect, confirmConnect, type ConnectDetails } from "./api";

export function ConnectAccountCard({ onLinked }: { onLinked: () => void }) {
  const t = useTranslations("payouts");
  const [accountId, setAccountId] = useState("");
  const [details, setDetails] = useState<ConnectDetails | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const idValid = /^acc_[A-Za-z0-9]+$/.test(accountId.trim());

  async function onVerify() {
    setBusy(true);
    setError(null);
    try {
      setDetails(await verifyConnect(accountId.trim()));
    } catch (e) {
      setError(e instanceof Error ? e.message : t("connect.errors.verify"));
    } finally {
      setBusy(false);
    }
  }

  async function onConfirm() {
    setBusy(true);
    setError(null);
    try {
      await confirmConnect(accountId.trim());
      onLinked();
    } catch (e) {
      setError(e instanceof Error ? e.message : t("connect.errors.link"));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="max-w-content rounded-lg border border-hairline p-lg">
      <div className="flex items-center gap-sm">
        <span className="flex size-9 items-center justify-center rounded-md bg-surface-tint text-ink">
          <Link2 size={18} />
        </span>
        <div>
          <p className="text-title-sm font-semibold text-ink">{t("connect.title")}</p>
          <p className="text-body-sm text-muted">
            {t("connect.subtitle")}
          </p>
        </div>
      </div>

      <div className="mt-md flex flex-wrap gap-sm">
        <input
          value={accountId}
          onChange={(e) => {
            setAccountId(e.target.value);
            setDetails(null);
          }}
          placeholder="acc_XXXXXXXXXXXX"
          className="h-10 flex-1 rounded-input border border-hairline bg-canvas px-md font-mono text-body-sm text-ink outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
        />
        {!details ? (
          <button
            type="button"
            onClick={onVerify}
            disabled={!idValid || busy}
            className="inline-flex h-10 items-center gap-sm rounded-button bg-brand px-lg text-label-md text-white hover:bg-brand-strong disabled:bg-disabled"
          >
            {busy ? <Loader2 size={15} className="animate-spin" /> : null} {t("connect.verify")}
          </button>
        ) : null}
      </div>

      {error ? (
        <p className="mt-sm rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      {details ? (
        <div className="mt-md rounded-md bg-surface-tint p-md">
          <p className="text-body-sm text-muted">{t("connect.confirmPrompt")}</p>
          <dl className="mt-sm grid grid-cols-2 gap-x-xl gap-y-xs text-body-sm">
            <Fact label={t("connect.fact.account")} value={details.accountId} />
            <Fact label={t("connect.fact.business")} value={details.legalBusinessName ?? "—"} />
            <Fact label={t("connect.fact.contact")} value={details.contactName ?? "—"} />
            <Fact label={t("connect.fact.email")} value={details.email ?? "—"} />
            <Fact label={t("connect.fact.kycStatus")} value={details.kycStatus} />
            <Fact label={t("connect.fact.payouts")} value={details.payoutsEnabled ? t("value.enabled") : t("value.notYetEnabled")} />
          </dl>
          {!details.payoutsEnabled ? (
            <p className="mt-sm text-body-sm text-warning">
              {t("connect.payoutsNotEnabledWarning")}
            </p>
          ) : null}
          <div className="mt-md flex items-center gap-sm">
            <button
              type="button"
              onClick={onConfirm}
              disabled={busy}
              className="inline-flex h-10 items-center gap-sm rounded-button bg-brand px-lg text-label-md text-white hover:bg-brand-strong disabled:bg-disabled"
            >
              {busy ? <Loader2 size={15} className="animate-spin" /> : <CheckCircle2 size={15} />} {t("connect.linkThisAccount")}
            </button>
            <button
              type="button"
              onClick={() => setDetails(null)}
              className="inline-flex h-10 items-center rounded-button border border-hairline px-lg text-label-md text-ink hover:bg-surface-tint"
            >
              {t("cancel")}
            </button>
          </div>
        </div>
      ) : null}
    </div>
  );
}

function Fact({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex flex-col gap-px">
      <dt className="text-label-md text-subtle">{label}</dt>
      <dd className="break-all text-body-md text-ink">{value}</dd>
    </div>
  );
}

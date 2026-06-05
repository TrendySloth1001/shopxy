"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { ArrowDownLeft, ArrowUpRight, Gavel, Merge, PiggyBank } from "lucide-react";
import { BackLink } from "@/shared/ui/page-header";
import { formatDateTime } from "@/shared/datetime";
import { formatINR } from "@/shared/money";
import { getCautionHistory, type CautionHistory } from "@/features/caution/api";
import { CAUTION_TXN_META, type CautionTxn } from "@/features/caution/schema";
import { ListRowsSkeleton } from "@/shared/ui/skeleton";

export default function CautionHistoryPage() {
  const params = useParams<{ id: string }>();
  const id = Number(params.id);
  const back = `/dashboard/parties/${id}`;

  const [data, setData] = useState<CautionHistory | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const h = await getCautionHistory(id);
        if (active) setData(h);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : "Could not load caution history.");
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [id]);

  return (
    <div className="w-full px-lg py-xxl pb-massive md:px-xxl">
      <BackLink href={back} label="Customer" />

      <div className="mt-md flex items-center gap-md">
        <span className="flex size-12 shrink-0 items-center justify-center rounded-lg bg-info-soft text-info">
          <PiggyBank size={24} />
        </span>
        <div>
          <h1 className="text-headline-md text-ink">Caution deposits</h1>
          <p className="mt-xs text-body-sm text-subtle">
            Held on file: <span className="font-semibold text-info">{formatINR(data?.balance ?? 0)}</span>
          </p>
        </div>
      </div>

      {error ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      <div className="mt-xl">
        {loading ? (
          <ListRowsSkeleton />
        ) : !data || data.data.length === 0 ? (
          <div className="flex flex-col items-center gap-md py-xxxl text-center">
            <span className="flex size-12 items-center justify-center rounded-full bg-surface-tint text-subtle">
              <PiggyBank size={22} />
            </span>
            <p className="text-body-md text-muted">No caution movements on file yet.</p>
          </div>
        ) : (
          data.data.map((t) => <CautionRow key={t.id} txn={t} />)
        )}
      </div>
    </div>
  );
}

function CautionRow({ txn }: { txn: CautionTxn }) {
  const meta = CAUTION_TXN_META[txn.type] ?? { label: txn.type, sign: "+" as const, tone: "in" as const };
  const inTone = meta.tone === "in";
  const detail = [
    txn.type === "ADJUSTMENT" ? txn.invoiceNo : txn.mode,
    txn.receiptNo,
    txn.type === "FORFEIT" && txn.gstTreatment === "SUPPLY" ? "GST applies" : null,
  ]
    .filter(Boolean)
    .join(" · ");

  return (
    <div className="flex items-start gap-md border-b border-hairline py-md">
      <span
        className={`mt-px flex size-9 shrink-0 items-center justify-center rounded-full ${
          inTone ? "bg-success-soft text-success" : "bg-error-soft text-error"
        }`}
      >
        {txn.type === "DEPOSIT" ? (
          <ArrowDownLeft size={16} />
        ) : txn.type === "ADJUSTMENT" ? (
          <Merge size={16} />
        ) : txn.type === "FORFEIT" ? (
          <Gavel size={16} />
        ) : (
          <ArrowUpRight size={16} />
        )}
      </span>
      <div className="min-w-0 flex-1">
        <p className="text-body-md text-ink">{meta.label}</p>
        <p className="text-body-sm text-muted">
          {formatDateTime(txn.createdAt)}
          {detail ? ` · ${detail}` : ""}
        </p>
        {txn.note ? <p className="mt-px text-body-sm text-subtle">{txn.note}</p> : null}
      </div>
      <p className={`shrink-0 text-body-md font-semibold ${inTone ? "text-success" : "text-error"}`}>
        {meta.sign}
        {formatINR(txn.amount)}
      </p>
    </div>
  );
}

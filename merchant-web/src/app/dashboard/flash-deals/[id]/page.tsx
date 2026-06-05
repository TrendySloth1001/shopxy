"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { Pencil, StopCircle } from "lucide-react";
import { BackLink } from "@/shared/ui/page-header";
import { Divider } from "@/shared/ui/divider";
import { Modal, ModalActions } from "@/shared/ui/modal";
import { formatDateRange } from "@/shared/datetime";
import { cancelFlashDeal, getFlashDeal } from "@/features/flash-deals/api";
import { discountPct, flashBucket, money } from "@/features/flash-deals/format";
import { FlashCardPreview } from "@/features/flash-deals/flash-deal-editor";
import { FlashAnalyticsPanel } from "@/features/flash-deals/analytics-panel";
import { FLASH_STATUS_LABELS, type FlashSale } from "@/features/flash-deals/schema";
import { DetailSkeleton } from "@/shared/ui/skeleton";

const BACK = "/dashboard/flash-deals";

const STATUS_CLASSES: Record<string, string> = {
  active: "bg-success-soft text-success",
  scheduled: "bg-accent-amber-soft text-accent-amber",
  past: "bg-surface-tint text-muted",
};

export default function FlashDealDetailPage() {
  const params = useParams<{ id: string }>();
  const id = Number(params.id);
  const router = useRouter();

  const [deal, setDeal] = useState<FlashSale | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [confirmCancel, setConfirmCancel] = useState(false);
  const [cancelBusy, setCancelBusy] = useState(false);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const d = await getFlashDeal(id);
        if (active) setDeal(d);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : "Could not load the flash deal.");
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [id]);

  async function onCancel() {
    setCancelBusy(true);
    try {
      await cancelFlashDeal(id);
      router.push(BACK);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not cancel the flash deal.");
      setCancelBusy(false);
      setConfirmCancel(false);
    }
  }

  if (loading) {
    return <DetailSkeleton />;
  }
  if (error || !deal) {
    return (
      <div className="w-full px-lg py-xxl md:px-xxl">
        <BackLink href={BACK} label="Flash deals" />
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">
          {error ?? "Flash deal not found."}
        </p>
      </div>
    );
  }

  const bucket = flashBucket(deal);
  const off = deal.product ? discountPct(deal.product.mrp, deal.flashPrice) : 0;
  const product = deal.product
    ? {
        id: deal.product.id,
        name: deal.product.name,
        sku: deal.product.sku ?? "",
        mrp: deal.product.mrp,
        sellingPrice: deal.product.sellingPrice,
        imageUrl: deal.product.images[0]?.url ?? null,
      }
    : null;

  return (
    <div className="w-full px-lg py-xxl pb-massive md:px-xxl">
      <BackLink href={BACK} label="Flash deals" />

      <div className="mt-md flex flex-wrap items-start justify-between gap-md">
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-sm">
            <h1 className="text-headline-md text-ink">
              {deal.product?.name ?? `Product #${deal.productId}`}
            </h1>
            <span
              className={`inline-flex shrink-0 items-center rounded-full px-sm py-px text-body-sm font-semibold ${STATUS_CLASSES[bucket]}`}
            >
              {FLASH_STATUS_LABELS[bucket]}
            </span>
          </div>
          <p className="mt-xs text-body-md text-muted">{formatDateRange(deal.startAt, deal.endAt)}</p>
        </div>
        <div className="flex shrink-0 items-center gap-sm">
          {bucket !== "past" ? (
            <button
              type="button"
              onClick={() => setConfirmCancel(true)}
              className="inline-flex h-10 items-center gap-sm rounded-button px-md text-label-md text-muted transition-colors hover:bg-error-soft hover:text-error"
            >
              <StopCircle size={16} /> Cancel
            </button>
          ) : null}
          <Link
            href={`/dashboard/flash-deals/${id}/edit`}
            className="inline-flex h-10 items-center gap-sm rounded-button bg-brand px-md text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            <Pencil size={16} /> Edit
          </Link>
        </div>
      </div>

      <div className="mt-xl grid gap-xl lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)] xl:grid-cols-[420px_minmax(0,1fr)]">
        {/* Preview */}
        <div>
          <p className="mb-sm text-label-md uppercase tracking-wide text-subtle">Customer card</p>
          <FlashCardPreview
            product={product}
            flashPrice={deal.flashPrice}
            off={off}
            sold={deal.soldCount}
            stockLimit={deal.stockLimit}
          />
          <dl className="mt-lg grid grid-cols-2 gap-x-xxl gap-y-md">
            <Fact label="Flash price" value={money(deal.flashPrice)} />
            <Fact label="MRP" value={deal.product ? money(deal.product.mrp) : "—"} />
            <Fact label="Discount" value={off > 0 ? `${off}% off` : "—"} />
            <Fact label="Stock cap" value={String(deal.stockLimit)} />
          </dl>
        </div>

        {/* Analytics inline */}
        <div>
          <p className="mb-sm text-label-md uppercase tracking-wide text-subtle">Performance</p>
          <FlashAnalyticsPanel id={id} />
        </div>
      </div>

      <Divider className="my-xl" />

      {confirmCancel ? (
        <Modal title="Cancel flash deal?" onClose={() => setConfirmCancel(false)}>
          <p className="text-body-md text-muted">
            Stops accepting new buyers at the discounted price. Already-claimed units stay claimed.
          </p>
          <ModalActions
            busy={cancelBusy}
            danger
            confirmLabel="Cancel sale"
            onCancel={() => setConfirmCancel(false)}
            onConfirm={onCancel}
          />
        </Modal>
      ) : null}
    </div>
  );
}

function Fact({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex flex-col gap-px border-b border-hairline pb-sm">
      <dt className="text-label-md text-subtle">{label}</dt>
      <dd className="text-body-md text-ink">{value}</dd>
    </div>
  );
}

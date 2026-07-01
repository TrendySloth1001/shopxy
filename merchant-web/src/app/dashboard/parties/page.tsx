"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useTranslations } from "next-intl";
import {
  BadgeCheck,
  ClipboardList,
  Pencil,
  Plus,
  ReceiptText,
  RefreshCw,
  Search,
  Trash2,
  Users,
} from "lucide-react";
import { PageHeader } from "@/shared/ui/page-header";
import { Monogram } from "@/shared/ui/monogram";
import { Modal, ModalActions } from "@/shared/ui/modal";
import { deleteParty, listParties } from "@/features/parties/api";
import { partyChallanCount, partyInvoiceCount, type Party } from "@/features/parties/schema";
import { MaybeLocked } from "@/features/auth/components/maybe-locked";
import { useCanManage } from "@/features/auth/use-can";
import { ListRowsSkeleton } from "@/shared/ui/skeleton";

export default function PartiesPage() {
  const t = useTranslations("parties");
  const [parties, setParties] = useState<Party[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [nonce, setNonce] = useState(0);
  const [searchInput, setSearchInput] = useState("");
  const [search, setSearch] = useState("");
  const [deleteTarget, setDeleteTarget] = useState<Party | null>(null);
  const [deleteBusy, setDeleteBusy] = useState(false);
  const canEdit = useCanManage("parties");

  const reload = useCallback(() => setNonce((n) => n + 1), []);

  useEffect(() => {
    const t = setTimeout(() => setSearch(searchInput.trim()), 300);
    return () => clearTimeout(t);
  }, [searchInput]);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const rows = await listParties({ search });
        if (!active) return;
        setParties(rows);
        setError(null);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : t("errors.loadList"));
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [nonce, search, t]);

  async function confirmDelete() {
    if (!deleteTarget) return;
    setDeleteBusy(true);
    try {
      await deleteParty(deleteTarget.id);
      setDeleteTarget(null);
      reload();
    } catch (e) {
      setError(e instanceof Error ? e.message : t("errors.delete"));
    } finally {
      setDeleteBusy(false);
    }
  }

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <PageHeader
        icon={Users}
        tone="indigo"
        title={t("list.title")}
        subtitle={t("list.subtitle")}
      >
        <button
          type="button"
          onClick={reload}
          disabled={loading}
          aria-label={t("actions.refresh")}
          className="inline-flex size-10 items-center justify-center rounded-button border border-hairline text-ink transition-colors hover:bg-surface-tint disabled:text-disabled"
        >
          <RefreshCw size={16} />
        </button>
        <MaybeLocked area="parties" label={t("actions.add")}>
          <Link
            href="/dashboard/parties/new"
            className="inline-flex h-10 items-center gap-sm rounded-button bg-brand px-md text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            <Plus size={16} /> {t("actions.add")}
          </Link>
        </MaybeLocked>
      </PageHeader>

      {/* Search */}
      <div className="mt-xl flex items-center gap-sm rounded-input border border-hairline bg-field px-md focus-within:border-brand focus-within:ring-2 focus-within:ring-brand-soft">
        <Search size={16} className="shrink-0 text-subtle" />
        <input
          value={searchInput}
          onChange={(e) => setSearchInput(e.target.value)}
          placeholder={t("list.searchPlaceholder")}
          className="h-10 w-full bg-transparent text-body-md text-ink outline-none placeholder:text-subtle"
        />
      </div>

      {error ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      <div className="mt-lg">
        {loading ? (
          <ListRowsSkeleton />
        ) : parties.length === 0 ? (
          <div className="flex flex-col items-center gap-md py-xxxl text-center">
            <span className="flex size-12 items-center justify-center rounded-full bg-accent-indigo-soft text-accent-indigo">
              <Users size={22} />
            </span>
            <p className="text-body-md text-muted">
              {search ? t("list.emptySearch") : t("list.empty")}
            </p>
            {!search ? (
              <MaybeLocked area="parties" label={t("actions.add")}>
                <Link
                  href="/dashboard/parties/new"
                  className="inline-flex h-10 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint"
                >
                  <Plus size={16} /> {t("actions.add")}
                </Link>
              </MaybeLocked>
            ) : null}
          </div>
        ) : (
          parties.map((p) => (
            <PartyRow key={p.id} party={p} canEdit={canEdit} onDelete={() => setDeleteTarget(p)} />
          ))
        )}
      </div>

      {deleteTarget ? (
        <Modal title={t("delete.title", { name: deleteTarget.name })} onClose={() => setDeleteTarget(null)}>
          <p className="text-body-md text-muted">
            {partyInvoiceCount(deleteTarget) + partyChallanCount(deleteTarget) > 0
              ? t("delete.bodyWithRecords", {
                  name: deleteTarget.name,
                  invoices: partyInvoiceCount(deleteTarget),
                  challans: partyChallanCount(deleteTarget),
                })
              : t("delete.bodyEmpty")}
          </p>
          <ModalActions
            busy={deleteBusy}
            danger
            confirmLabel={t("delete.confirm")}
            onCancel={() => setDeleteTarget(null)}
            onConfirm={confirmDelete}
          />
        </Modal>
      ) : null}
    </div>
  );
}

function PartyRow({
  party,
  canEdit,
  onDelete,
}: {
  party: Party;
  canEdit: boolean;
  onDelete: () => void;
}) {
  const t = useTranslations("parties");
  const challans = partyChallanCount(party);
  const invoices = partyInvoiceCount(party);
  return (
    <div className="flex items-center gap-md border-b border-hairline py-md">
      <Link href={`/dashboard/parties/${party.id}`} className="flex min-w-0 flex-1 items-center gap-md">
        <Monogram name={party.name} />
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-sm">
            <span className="truncate text-body-md text-ink">{party.name}</span>
            {party.linkedUserId ? (
              <span className="inline-flex items-center gap-xs rounded-full bg-success-soft px-sm py-px text-body-sm font-semibold text-success">
                <BadgeCheck size={12} /> {t("badges.linked")}
              </span>
            ) : null}
            {!party.isActive ? (
              <span className="inline-flex items-center rounded-full bg-surface-tint px-sm py-px text-body-sm font-semibold text-muted">
                {t("badges.inactive")}
              </span>
            ) : null}
          </div>
          <p className="truncate text-body-sm text-muted">
            {party.phone ?? t("row.noPhone")}
            {party.gstin ? ` · GSTIN ${party.gstin}` : ""}
          </p>
          <p className="mt-px flex items-center gap-md text-body-sm text-subtle">
            <span className="inline-flex items-center gap-xs">
              <ClipboardList size={13} /> {t("row.challanCount", { count: challans })}
            </span>
            <span className="inline-flex items-center gap-xs">
              <ReceiptText size={13} /> {t("row.invoiceCount", { count: invoices })}
            </span>
          </p>
        </div>
      </Link>
      <div className="flex shrink-0 items-center">
        <Link
          href={`/dashboard/parties/${party.id}/edit`}
          aria-label={t("actions.edit")}
          className="inline-flex size-9 items-center justify-center rounded-button text-muted transition-colors hover:bg-surface-tint hover:text-ink"
        >
          <Pencil size={16} />
        </Link>
        <button
          type="button"
          onClick={onDelete}
          disabled={!canEdit}
          aria-label={t("actions.delete")}
          title={canEdit ? undefined : t("row.noAccess")}
          className="inline-flex size-9 items-center justify-center rounded-button text-muted transition-colors hover:bg-error-soft hover:text-error disabled:text-disabled disabled:hover:bg-transparent"
        >
          <Trash2 size={16} />
        </button>
      </div>
    </div>
  );
}

"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import {
  BadgeCheck,
  Package,
  Pencil,
  Plus,
  ReceiptText,
  RefreshCw,
  Search,
  Trash2,
  Truck,
} from "lucide-react";
import { PageHeader } from "@/shared/ui/page-header";
import { Monogram } from "@/shared/ui/monogram";
import { Modal, ModalActions } from "@/shared/ui/modal";
import { deleteVendor, listVendors } from "@/features/vendors/api";
import { vendorInvoiceCount, vendorTxnCount, type Vendor } from "@/features/vendors/schema";
import { MaybeLocked } from "@/features/auth/components/maybe-locked";
import { useCanManage } from "@/features/auth/use-can";
import { ListRowsSkeleton } from "@/shared/ui/skeleton";

export default function VendorsPage() {
  const [vendors, setVendors] = useState<Vendor[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [nonce, setNonce] = useState(0);
  const [searchInput, setSearchInput] = useState("");
  const [search, setSearch] = useState("");
  const [deleteTarget, setDeleteTarget] = useState<Vendor | null>(null);
  const [deleteBusy, setDeleteBusy] = useState(false);
  const canEdit = useCanManage("vendors");

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
        const rows = await listVendors({ search });
        if (!active) return;
        setVendors(rows);
        setError(null);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : "Could not load vendors.");
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [nonce, search]);

  async function confirmDelete() {
    if (!deleteTarget) return;
    setDeleteBusy(true);
    try {
      await deleteVendor(deleteTarget.id);
      setDeleteTarget(null);
      reload();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not delete the vendor.");
    } finally {
      setDeleteBusy(false);
    }
  }

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <PageHeader
        icon={Truck}
        tone="amber"
        title="Vendors"
        subtitle="Suppliers you buy from. Track purchase bills, stock-in and the running payable for each."
      >
        <button
          type="button"
          onClick={reload}
          disabled={loading}
          aria-label="Refresh"
          className="inline-flex size-10 items-center justify-center rounded-button border border-hairline text-ink transition-colors hover:bg-surface-tint disabled:text-disabled"
        >
          <RefreshCw size={16} />
        </button>
        <MaybeLocked area="vendors" label="Add vendor">
          <Link
            href="/dashboard/vendors/new"
            className="inline-flex h-10 items-center gap-sm rounded-button bg-brand px-md text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            <Plus size={16} /> Add vendor
          </Link>
        </MaybeLocked>
      </PageHeader>

      {/* Search */}
      <div className="mt-xl flex items-center gap-sm rounded-input border border-hairline bg-field px-md focus-within:border-brand focus-within:ring-2 focus-within:ring-brand-soft">
        <Search size={16} className="shrink-0 text-subtle" />
        <input
          value={searchInput}
          onChange={(e) => setSearchInput(e.target.value)}
          placeholder="Search by name, phone, email or GSTIN"
          className="h-10 w-full bg-transparent text-body-md text-ink outline-none placeholder:text-subtle"
        />
      </div>

      {error ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      <div className="mt-lg">
        {loading ? (
          <ListRowsSkeleton />
        ) : vendors.length === 0 ? (
          <div className="flex flex-col items-center gap-md py-xxxl text-center">
            <span className="flex size-12 items-center justify-center rounded-full bg-accent-amber-soft text-accent-amber">
              <Truck size={22} />
            </span>
            <p className="text-body-md text-muted">
              {search ? "No vendors match your search." : "No vendors yet — add your first supplier."}
            </p>
            {!search ? (
              <MaybeLocked area="vendors" label="Add vendor">
                <Link
                  href="/dashboard/vendors/new"
                  className="inline-flex h-10 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint"
                >
                  <Plus size={16} /> Add vendor
                </Link>
              </MaybeLocked>
            ) : null}
          </div>
        ) : (
          vendors.map((v) => (
            <VendorRow key={v.id} vendor={v} canEdit={canEdit} onDelete={() => setDeleteTarget(v)} />
          ))
        )}
      </div>

      {deleteTarget ? (
        <Modal title={`Delete ${deleteTarget.name}?`} onClose={() => setDeleteTarget(null)}>
          <p className="text-body-md text-muted">
            Removes the vendor. If they have bills or stock-in history they&rsquo;re deactivated instead, so
            past records stay intact.
          </p>
          <ModalActions
            busy={deleteBusy}
            danger
            confirmLabel="Delete"
            onCancel={() => setDeleteTarget(null)}
            onConfirm={confirmDelete}
          />
        </Modal>
      ) : null}
    </div>
  );
}

function VendorRow({
  vendor,
  canEdit,
  onDelete,
}: {
  vendor: Vendor;
  canEdit: boolean;
  onDelete: () => void;
}) {
  const txns = vendorTxnCount(vendor);
  const invoices = vendorInvoiceCount(vendor);
  return (
    <div className="flex items-center gap-md border-b border-hairline py-md">
      <Link href={`/dashboard/vendors/${vendor.id}`} className="flex min-w-0 flex-1 items-center gap-md">
        <Monogram name={vendor.name} />
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-sm">
            <span className="truncate text-body-md text-ink">{vendor.name}</span>
            {vendor.linkedUserId ? (
              <span className="inline-flex items-center gap-xs rounded-full bg-success-soft px-sm py-px text-body-sm font-semibold text-success">
                <BadgeCheck size={12} /> Linked
              </span>
            ) : null}
            {!vendor.isActive ? (
              <span className="inline-flex items-center rounded-full bg-surface-tint px-sm py-px text-body-sm font-semibold text-muted">
                Inactive
              </span>
            ) : null}
          </div>
          <p className="truncate text-body-sm text-muted">
            {vendor.phone ?? "No phone"}
            {vendor.gstin ? ` · GSTIN ${vendor.gstin}` : ""}
          </p>
          <p className="mt-px flex items-center gap-md text-body-sm text-subtle">
            <span className="inline-flex items-center gap-xs">
              <Package size={13} /> {txns} {txns === 1 ? "txn" : "txns"}
            </span>
            <span className="inline-flex items-center gap-xs">
              <ReceiptText size={13} /> {invoices} {invoices === 1 ? "invoice" : "invoices"}
            </span>
          </p>
        </div>
      </Link>
      <div className="flex shrink-0 items-center">
        <Link
          href={`/dashboard/vendors/${vendor.id}/edit`}
          aria-label="Edit"
          className="inline-flex size-9 items-center justify-center rounded-button text-muted transition-colors hover:bg-surface-tint hover:text-ink"
        >
          <Pencil size={16} />
        </Link>
        <button
          type="button"
          onClick={onDelete}
          disabled={!canEdit}
          aria-label="Delete"
          title={canEdit ? undefined : "You don't have access. Ask the shop owner."}
          className="inline-flex size-9 items-center justify-center rounded-button text-muted transition-colors hover:bg-error-soft hover:text-error disabled:text-disabled disabled:hover:bg-transparent"
        >
          <Trash2 size={16} />
        </button>
      </div>
    </div>
  );
}

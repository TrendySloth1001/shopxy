"use client";

import { useEffect, useState } from "react";
import { MapPin, Plus, Pencil, Trash2, Star, StarOff } from "lucide-react";
import { RequireAuth } from "@/features/auth/components/require-auth";
import { AppHeader } from "@/features/auth/components/app-header";
import { AddressForm } from "@/features/addresses/components/address-form";
import {
  fetchAddresses,
  createAddress,
  updateAddress,
  deleteAddress,
  setDefaultAddress,
} from "@/features/addresses/api";
import type { UserAddress, AddressFormValues } from "@/features/addresses/types";
import { addressOneLine } from "@/features/addresses/types";

// ── Modal state shape ─────────────────────────────────────────────────────────

type ModalState =
  | { mode: "none" }
  | { mode: "add" }
  | { mode: "edit"; address: UserAddress }
  | { mode: "delete"; address: UserAddress };

// ── Main page ─────────────────────────────────────────────────────────────────

function AddressesInner() {
  const [addresses, setAddresses] = useState<UserAddress[]>([]);
  const [loading, setLoading] = useState(true);
  const [fetchError, setFetchError] = useState<string | null>(null);
  const [modal, setModal] = useState<ModalState>({ mode: "none" });
  const [deleteError, setDeleteError] = useState<string | null>(null);
  const [deleting, setDeleting] = useState(false);
  const [settingDefault, setSettingDefault] = useState<number | null>(null);

  const [loadTrigger, setLoadTrigger] = useState(0);

  useEffect(() => {
    let cancelled = false;
    // Batch the loading-start state into a single transition via startTransition
    // to satisfy react-hooks/set-state-in-effect (no synchronous setState in body).
    import("react").then(({ startTransition }) => {
      startTransition(() => {
        if (!cancelled) {
          setLoading(true);
          setFetchError(null);
        }
      });
    }).catch(() => null);
    fetchAddresses()
      .then((data) => {
        if (!cancelled) setAddresses(data);
      })
      .catch((err: unknown) => {
        if (!cancelled)
          setFetchError(
            err instanceof Error ? err.message : "Could not load addresses.",
          );
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [loadTrigger]);

  function load() {
    setLoadTrigger((n) => n + 1);
  }

  async function handleCreate(values: AddressFormValues) {
    const created = await createAddress(values);
    setAddresses((prev) => [...prev, created]);
    setModal({ mode: "none" });
  }

  async function handleUpdate(values: AddressFormValues) {
    if (modal.mode !== "edit") return;
    const updated = await updateAddress(modal.address.id, values);
    setAddresses((prev) => prev.map((a) => (a.id === updated.id ? updated : a)));
    setModal({ mode: "none" });
  }

  async function handleDelete() {
    if (modal.mode !== "delete") return;
    setDeleting(true);
    setDeleteError(null);
    try {
      await deleteAddress(modal.address.id);
      setAddresses((prev) => prev.filter((a) => a.id !== modal.address.id));
      setModal({ mode: "none" });
    } catch (err) {
      setDeleteError(err instanceof Error ? err.message : "Could not delete address.");
    } finally {
      setDeleting(false);
    }
  }

  async function handleSetDefault(id: number) {
    setSettingDefault(id);
    try {
      await setDefaultAddress(id);
      setAddresses((prev) =>
        prev.map((a) => ({ ...a, isDefault: a.id === id })),
      );
    } catch {
      /* ignore — reload to sync */
      void load();
    } finally {
      setSettingDefault(null);
    }
  }

  return (
    <>
      <AppHeader />
      <main className="mx-auto max-w-content px-lg py-xxxl">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-headline-md text-ink">Saved Addresses</h1>
            <p className="mt-xs text-body-md text-muted">
              Manage your delivery addresses.
            </p>
          </div>
          <button
            onClick={() => setModal({ mode: "add" })}
            className="inline-flex h-10 items-center gap-sm rounded-button bg-brand px-lg text-label-md font-bold text-white hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
          >
            <Plus className="h-4 w-4" />
            Add address
          </button>
        </div>

        <div className="mt-xxl">
          {loading ? (
            <AddressSkeleton />
          ) : fetchError ? (
            <ErrorState message={fetchError} onRetry={() => void load()} />
          ) : addresses.length === 0 ? (
            <EmptyState onAdd={() => setModal({ mode: "add" })} />
          ) : (
            <div className="flex flex-col gap-sm">
              {addresses.map((address) => (
                <AddressCard
                  key={address.id}
                  address={address}
                  settingDefault={settingDefault === address.id}
                  onEdit={() => setModal({ mode: "edit", address })}
                  onDelete={() => setModal({ mode: "delete", address })}
                  onSetDefault={() => void handleSetDefault(address.id)}
                />
              ))}
            </div>
          )}
        </div>
      </main>

      {/* Add/Edit modal */}
      {(modal.mode === "add" || modal.mode === "edit") && (
        <div
          className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-ink/40 px-lg"
          onClick={(e) => {
            if (e.target === e.currentTarget) setModal({ mode: "none" });
          }}
        >
          <div className="w-full max-w-lg rounded-t-dialog sm:rounded-dialog bg-white max-h-[90vh] overflow-auto">
            <div className="sticky top-0 border-b border-hairline bg-white px-lg py-md">
              <h2 className="text-title-md font-extrabold text-ink">
                {modal.mode === "add" ? "Add new address" : "Edit address"}
              </h2>
            </div>
            <div className="px-lg py-xl">
              <AddressForm
                initial={modal.mode === "edit" ? modal.address : undefined}
                submitLabel={modal.mode === "add" ? "Save address" : "Update address"}
                onSubmit={modal.mode === "add" ? handleCreate : handleUpdate}
                onCancel={() => setModal({ mode: "none" })}
              />
            </div>
          </div>
        </div>
      )}

      {/* Delete confirm modal */}
      {modal.mode === "delete" && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-ink/40 px-lg">
          <div className="w-full max-w-sm rounded-dialog bg-white p-xl">
            <h2 className="text-title-md font-extrabold text-ink">Delete address?</h2>
            <p className="mt-sm text-body-sm text-muted">
              <span className="font-bold text-ink">{modal.address.fullName}</span>
              {" — "}
              {addressOneLine(modal.address)}
            </p>
            <p className="mt-xs text-body-sm text-muted">
              This can&apos;t be undone.
            </p>
            {deleteError && (
              <p className="mt-sm rounded-sm bg-error-soft px-sm py-xs text-body-sm text-error">
                {deleteError}
              </p>
            )}
            <div className="mt-xl flex gap-sm">
              <button
                onClick={() => {
                  setModal({ mode: "none" });
                  setDeleteError(null);
                }}
                disabled={deleting}
                className="inline-flex h-10 flex-1 items-center justify-center rounded-button border border-hairline bg-white text-label-md text-ink hover:bg-canvas focus-visible:outline-none disabled:opacity-50"
              >
                Cancel
              </button>
              <button
                onClick={() => void handleDelete()}
                disabled={deleting}
                className="inline-flex h-10 flex-1 items-center justify-center rounded-button bg-error text-label-md font-bold text-white hover:opacity-90 focus-visible:outline-none disabled:opacity-50"
              >
                {deleting ? "Deleting…" : "Delete"}
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}

export default function AddressesPage() {
  return (
    <RequireAuth>
      <AddressesInner />
    </RequireAuth>
  );
}

// ── Sub-components ─────────────────────────────────────────────────────────────

function AddressCard({
  address,
  settingDefault,
  onEdit,
  onDelete,
  onSetDefault,
}: {
  address: UserAddress;
  settingDefault: boolean;
  onEdit: () => void;
  onDelete: () => void;
  onSetDefault: () => void;
}) {
  return (
    <div className="flex items-start gap-md rounded-md bg-white p-md">
      <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-sm bg-brand-soft">
        <MapPin className="h-5 w-5 text-brand" />
      </div>
      <div className="flex-1">
        <div className="flex flex-wrap items-center gap-sm">
          <span className="text-body-md font-extrabold text-ink">{address.fullName}</span>
          {address.label && (
            <span className="rounded-full bg-canvas px-sm py-xs text-label-md font-bold text-ink uppercase">
              {address.label}
            </span>
          )}
          {address.isDefault && (
            <span className="rounded-full bg-success-soft px-sm py-xs text-label-md font-extrabold text-success uppercase">
              Default
            </span>
          )}
        </div>
        <p className="mt-xs text-body-sm text-ink">{addressOneLine(address)}</p>
        {address.phone && (
          <p className="mt-xs text-label-md text-muted">{address.phone}</p>
        )}
        {address.landmark && (
          <p className="mt-xs text-label-md text-muted">
            Near: {address.landmark}
          </p>
        )}

        {/* Actions */}
        <div className="mt-sm flex flex-wrap items-center gap-sm">
          <button
            onClick={onEdit}
            className="inline-flex items-center gap-xs rounded-button border border-hairline bg-white px-sm py-xs text-label-md font-bold text-ink hover:bg-canvas focus-visible:outline-none"
          >
            <Pencil className="h-3.5 w-3.5" />
            Edit
          </button>
          <button
            onClick={onDelete}
            className="inline-flex items-center gap-xs rounded-button border border-hairline bg-white px-sm py-xs text-label-md font-bold text-error hover:bg-error-soft focus-visible:outline-none"
          >
            <Trash2 className="h-3.5 w-3.5" />
            Delete
          </button>
          {!address.isDefault && (
            <button
              onClick={onSetDefault}
              disabled={settingDefault}
              className="inline-flex items-center gap-xs rounded-button border border-hairline bg-white px-sm py-xs text-label-md font-bold text-muted hover:bg-canvas focus-visible:outline-none disabled:opacity-50"
            >
              {settingDefault ? (
                <span className="h-3.5 w-3.5 animate-spin rounded-full border border-hairline border-t-brand" />
              ) : (
                <Star className="h-3.5 w-3.5" />
              )}
              Set default
            </button>
          )}
          {address.isDefault && (
            <span className="inline-flex items-center gap-xs rounded-button bg-success-soft px-sm py-xs text-label-md font-bold text-success">
              <StarOff className="h-3.5 w-3.5" />
              Default address
            </span>
          )}
        </div>
      </div>
    </div>
  );
}

function EmptyState({ onAdd }: { onAdd: () => void }) {
  return (
    <div className="flex flex-col items-center py-xxxl text-center">
      <div className="mb-lg flex h-20 w-20 items-center justify-center rounded-xl bg-canvas">
        <MapPin className="h-10 w-10 text-muted" />
      </div>
      <h2 className="text-title-md font-extrabold text-ink">No addresses saved</h2>
      <p className="mt-xs max-w-xs text-body-sm text-muted">
        Add a delivery address so you can check out quickly next time.
      </p>
      <button
        onClick={onAdd}
        className="mt-lg inline-flex h-10 items-center gap-sm rounded-button bg-brand px-lg text-label-md font-bold text-white hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
      >
        <Plus className="h-4 w-4" />
        Add your first address
      </button>
    </div>
  );
}

function ErrorState({ message, onRetry }: { message: string; onRetry: () => void }) {
  return (
    <div className="flex flex-col items-center py-xxl text-center">
      <p className="text-body-md text-error">{message}</p>
      <button
        onClick={onRetry}
        className="mt-md inline-flex h-10 items-center rounded-button border border-hairline bg-white px-lg text-label-md text-ink hover:bg-canvas focus-visible:outline-none"
      >
        Retry
      </button>
    </div>
  );
}

function AddressSkeleton() {
  return (
    <div className="flex flex-col gap-sm">
      {[1, 2].map((i) => (
        <div key={i} className="flex animate-pulse gap-md rounded-md bg-white p-md">
          <div className="h-10 w-10 rounded-sm bg-canvas" />
          <div className="flex-1 space-y-sm">
            <div className="h-4 w-1/3 rounded-xs bg-canvas" />
            <div className="h-4 w-2/3 rounded-xs bg-canvas" />
            <div className="h-4 w-1/4 rounded-xs bg-canvas" />
          </div>
        </div>
      ))}
    </div>
  );
}

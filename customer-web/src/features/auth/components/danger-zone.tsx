"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "../auth-context";
import { Field } from "./field";
import { Banner } from "./banner";

/**
 * DPDP self-service: export my data (right-to-access) and delete my account
 * (right-to-erasure). Deletion requires re-entering the password.
 */
export function DangerZone() {
  const { exportData, deleteAccount } = useAuth();
  const router = useRouter();

  const [exporting, setExporting] = useState(false);
  const [exportError, setExportError] = useState<string | null>(null);

  const [confirming, setConfirming] = useState(false);
  const [password, setPassword] = useState("");
  const [deleteError, setDeleteError] = useState<string | null>(null);
  const [deleting, setDeleting] = useState(false);

  async function onExport() {
    setExportError(null);
    setExporting(true);
    try {
      await exportData();
    } catch (err) {
      setExportError(err instanceof Error ? err.message : "Could not export your data.");
    } finally {
      setExporting(false);
    }
  }

  async function onDelete() {
    if (!password) {
      setDeleteError("Enter your password to confirm.");
      return;
    }
    setDeleteError(null);
    setDeleting(true);
    try {
      await deleteAccount(password);
      router.replace("/login?reason=account-deleted");
    } catch (err) {
      setDeleteError(err instanceof Error ? err.message : "Could not delete your account.");
      setDeleting(false);
    }
  }

  return (
    <div className="flex flex-col gap-xl">
      <div className="flex flex-col gap-sm">
        <p className="text-body-md text-ink">Export my data</p>
        <p className="text-body-sm text-muted">
          Download a copy of your account data as JSON.
        </p>
        {exportError ? <Banner variant="error" message={exportError} /> : null}
        <button
          type="button"
          onClick={onExport}
          disabled={exporting}
          className="mt-xs inline-flex h-11 w-fit items-center justify-center rounded-button border border-hairline px-lg text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:text-disabled"
        >
          {exporting ? "Preparing…" : "Download my data"}
        </button>
      </div>

      <div className="flex flex-col gap-sm">
        <p className="text-body-md text-error">Delete my account</p>
        <p className="text-body-sm text-muted">
          Permanently delete your account and data. This cannot be undone.
        </p>
        {deleteError ? <Banner variant="error" message={deleteError} /> : null}
        {confirming ? (
          <div className="mt-xs flex flex-col gap-md">
            <Field
              label="Confirm your password"
              autoComplete="current-password"
              toggleable
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
            <div className="flex gap-md">
              <button
                type="button"
                onClick={onDelete}
                disabled={deleting}
                className="inline-flex h-11 items-center justify-center rounded-button bg-error px-lg text-label-md text-white transition-colors hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-error-soft disabled:bg-disabled"
              >
                {deleting ? "Deleting…" : "Permanently delete"}
              </button>
              <button
                type="button"
                onClick={() => {
                  setConfirming(false);
                  setPassword("");
                  setDeleteError(null);
                }}
                className="inline-flex h-11 items-center justify-center rounded-button px-lg text-label-md text-muted transition-colors hover:text-ink focus-visible:outline-none"
              >
                Cancel
              </button>
            </div>
          </div>
        ) : (
          <button
            type="button"
            onClick={() => setConfirming(true)}
            className="mt-xs inline-flex h-11 w-fit items-center justify-center rounded-button border border-error px-lg text-label-md text-error transition-colors hover:bg-error-soft focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-error-soft"
          >
            Delete account
          </button>
        )}
      </div>
    </div>
  );
}

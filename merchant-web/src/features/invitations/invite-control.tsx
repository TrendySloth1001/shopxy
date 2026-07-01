"use client";

import { useCallback, useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { UserPlus, X } from "lucide-react";
import { Modal, ModalActions } from "@/shared/ui/modal";
import { TextAreaField, TextField } from "@/shared/ui/form";
import {
  cancelInvitation,
  listOutgoingInvitations,
  sendInvitation,
  type LinkType,
} from "./api";
import type { Invitation } from "./schema";

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

/**
 * Invite-to-ShopXY control for a party/vendor detail header. Resolves this
 * contact's outgoing invite (if any): shows an "Invited · cancel" chip while
 * pending, or an "Invite" button otherwise. Renders nothing once the contact
 * has linked their account (the parent already shows a "Linked" badge).
 */
export function InviteControl({
  linkType,
  entityId,
  name,
  email,
  linked,
}: {
  linkType: LinkType;
  entityId: number;
  name: string;
  email?: string | null;
  linked: boolean;
}) {
  const t = useTranslations("notifications");
  const [invite, setInvite] = useState<Invitation | null>(null);
  const [open, setOpen] = useState(false);
  const [toEmail, setToEmail] = useState(email ?? "");
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const matches = useCallback(
    (i: Invitation) =>
      i.linkType === linkType && (linkType === "PARTY" ? i.partyId === entityId : i.vendorId === entityId),
    [linkType, entityId],
  );

  const load = useCallback(async () => {
    const all = await listOutgoingInvitations();
    const mine = all.filter(matches);
    const pending = mine.find((i) => i.status === "PENDING");
    setInvite(pending ?? mine[0] ?? null);
  }, [matches]);

  useEffect(() => {
    if (linked) return;
    let active = true;
    void (async () => {
      try {
        const all = await listOutgoingInvitations();
        if (!active) return;
        const mine = all.filter(matches);
        const pending = mine.find((i) => i.status === "PENDING");
        setInvite(pending ?? mine[0] ?? null);
      } catch {
        /* best-effort — the control just won't show a chip */
      }
    })();
    return () => {
      active = false;
    };
  }, [linked, matches]);

  if (linked) return null;

  const pending = invite?.status === "PENDING";

  async function cancel() {
    if (!invite) return;
    setBusy(true);
    try {
      await cancelInvitation(invite.id);
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : t("inviteControl.cancelError"));
    } finally {
      setBusy(false);
    }
  }

  async function send() {
    setError(null);
    if (!EMAIL_RE.test(toEmail.trim())) return setError(t("inviteControl.invalidEmail"));
    setBusy(true);
    try {
      await sendInvitation({
        toEmail: toEmail.trim(),
        linkType,
        ...(linkType === "PARTY" ? { partyId: entityId } : { vendorId: entityId }),
        message: message.trim() || undefined,
      });
      setOpen(false);
      setMessage("");
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : t("inviteControl.sendError"));
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      {pending ? (
        <span className="inline-flex items-center gap-xs rounded-full bg-accent-amber-soft py-px pl-sm pr-px text-body-sm font-semibold text-accent-amber">
          {t("inviteControl.invited")}
          <button
            type="button"
            onClick={cancel}
            disabled={busy}
            aria-label={t("inviteControl.cancelInvitation")}
            className="inline-flex size-5 items-center justify-center rounded-full transition-colors hover:bg-accent-amber-soft hover:text-error disabled:opacity-50"
          >
            <X size={13} />
          </button>
        </span>
      ) : (
        <button
          type="button"
          onClick={() => {
            setToEmail(email ?? "");
            setError(null);
            setOpen(true);
          }}
          disabled={!email}
          title={email ? undefined : t("inviteControl.addEmailFirst")}
          className="inline-flex h-10 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint disabled:text-disabled"
        >
          <UserPlus size={16} /> {t("inviteControl.invite")}
        </button>
      )}

      {open ? (
        <Modal title={t("inviteControl.modalTitle", { name })} onClose={() => setOpen(false)}>
          <p className="text-body-md text-muted">
            {linkType === "PARTY"
              ? t("inviteControl.explainerParty")
              : t("inviteControl.explainerVendor")}
          </p>
          {error ? (
            <p className="rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
          ) : null}
          <TextField label={t("inviteControl.emailLabel")} value={toEmail} onChange={setToEmail} type="email" />
          <TextAreaField label={t("inviteControl.messageLabel")} value={message} onChange={setMessage} rows={2} />
          <ModalActions busy={busy} confirmLabel={t("inviteControl.sendInvite")} onCancel={() => setOpen(false)} onConfirm={send} />
        </Modal>
      ) : null}
    </>
  );
}

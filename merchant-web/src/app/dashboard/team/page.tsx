"use client";

import { useCallback, useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { Plus, Pencil, Trash2, Mail, ShieldCheck, Link2, Check } from "lucide-react";
import { Divider } from "@/shared/ui/divider";
import { Modal, ModalActions } from "@/shared/ui/modal";
import { SideSheet } from "@/shared/ui/side-sheet";
import { Avatar } from "@/features/auth/components/avatar";
import {
  cancelInvite,
  createRole,
  deleteRole,
  listInvites,
  listMembers,
  listRoles,
  removeMember,
  sendInvite,
  setMemberPermissions,
  updateRole,
} from "@/features/team/api";
import type { Invite, Member, Role } from "@/features/team/schema";
import {
  normalizeRights,
  summaryAreas,
  type Area,
} from "@/features/team/permissions";
import { PermissionMatrix } from "@/features/team/permission-matrix";
import { useCanManage, useGrantCeiling } from "@/features/auth/use-can";
import { ListRowsSkeleton } from "@/shared/ui/skeleton";

/** Translated, comma-joined access summary, e.g. "Products, Orders +2". */
function useSummary() {
  const t = useTranslations("team");
  return (rights: readonly string[]): string => {
    const areas = summaryAreas(rights);
    if (areas.length === 0) return t("summary.none");
    const labels = areas.map((a) => t(`area.${a}.label` as `area.${Area}.label`));
    if (labels.length <= 3) return labels.join(", ");
    return `${labels.slice(0, 3).join(", ")} +${labels.length - 3}`;
  };
}

export default function TeamPage() {
  const [members, setMembers] = useState<Member[]>([]);
  const [invites, setInvites] = useState<Invite[]>([]);
  const [roles, setRoles] = useState<Role[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [nonce, setNonce] = useState(0);
  const [busy, setBusy] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);

  const [inviteOpen, setInviteOpen] = useState(false);
  const [editMember, setEditMember] = useState<Member | null>(null);
  const [roleEditor, setRoleEditor] = useState<Role | "new" | null>(null);
  const canEdit = useCanManage("team");
  const t = useTranslations("team");
  const summarise = useSummary();
  const lockTitle = t("lockTitle");

  const reload = useCallback(() => setNonce((n) => n + 1), []);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const [m, i, r] = await Promise.all([
          listMembers(),
          listInvites().catch(() => []),
          listRoles().catch(() => []),
        ]);
        if (!active) return;
        setMembers(m);
        setInvites(i);
        setRoles(r);
        setError(null);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : t("error.load"));
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [nonce]);

  async function run(fn: () => Promise<void>) {
    setBusy(true);
    setActionError(null);
    try {
      await fn();
      reload();
    } catch (e) {
      setActionError(e instanceof Error ? e.message : t("error.generic"));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <div className="flex flex-wrap items-start justify-between gap-md">
        <div>
          <h1 className="text-headline-md text-ink">{t("title")}</h1>
          <p className="mt-xs text-body-md text-muted">{t("subtitle")}</p>
        </div>
        <button
          type="button"
          onClick={() => setInviteOpen(true)}
          className="inline-flex h-10 items-center gap-sm rounded-button bg-brand px-lg text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
        >
          <Plus size={18} /> {t("invite.cta")}
        </button>
      </div>

      {actionError ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">
          {actionError}
        </p>
      ) : null}

      {loading ? (
        <ListRowsSkeleton />
      ) : error ? (
        <div className="mt-xl flex flex-col items-start gap-md">
          <p className="text-body-md text-muted">{error}</p>
          <button
            type="button"
            onClick={reload}
            className="inline-flex h-10 items-center rounded-button border border-hairline px-lg text-label-md text-ink transition-colors hover:bg-surface-tint"
          >
            {t("retry")}
          </button>
        </div>
      ) : (
        <>
          {/* Members */}
          <h2 className="mt-xl text-title-md text-ink">
            {t("members.title")} <span className="text-subtle">· {members.length}</span>
          </h2>
          <ul className="mt-sm">
            {members.map((m) => (
              <li
                key={m.id}
                className="flex items-center gap-md border-t border-hairline py-md"
              >
                <Avatar url={m.user.avatarUrl} name={m.user.name} size={40} />
                <div className="min-w-0 flex-1">
                  <p className="truncate text-body-md text-ink">{m.user.name}</p>
                  <p className="truncate text-body-sm text-muted">{m.user.email}</p>
                </div>
                <div className="hidden min-w-0 sm:block sm:w-64">
                  <p className="truncate text-body-sm text-ink">
                    {m.isOwner ? t("role.owner") : m.roleName || t("role.staff")}
                  </p>
                  <p className="truncate text-body-sm text-muted">
                    {m.isOwner ? t("role.fullAccess") : summarise(m.permissions)}
                  </p>
                </div>
                {m.isOwner ? (
                  <span className="rounded-full bg-brand-soft px-sm py-px text-body-sm text-brand-strong">
                    {t("role.owner")}
                  </span>
                ) : (
                  <div className="flex items-center gap-xs">
                    <button
                      type="button"
                      onClick={() => setEditMember(m)}
                      disabled={!canEdit}
                      aria-label={t("members.editAria")}
                      title={canEdit ? undefined : lockTitle}
                      className="rounded-md p-xs text-muted transition-colors hover:bg-surface-tint hover:text-ink disabled:text-disabled disabled:hover:bg-transparent"
                    >
                      <Pencil size={16} />
                    </button>
                    <button
                      type="button"
                      disabled={busy || !canEdit}
                      onClick={() => run(() => removeMember(m.user.id))}
                      aria-label={t("members.removeAria")}
                      title={canEdit ? undefined : lockTitle}
                      className="rounded-md p-xs text-muted transition-colors hover:bg-error-soft hover:text-error disabled:text-disabled disabled:hover:bg-transparent"
                    >
                      <Trash2 size={16} />
                    </button>
                  </div>
                )}
              </li>
            ))}
          </ul>

          {/* Pending invites */}
          {invites.length > 0 ? (
            <>
              <Divider className="my-xl" />
              <h2 className="text-title-md text-ink">
                {t("invites.title")} <span className="text-subtle">· {invites.length}</span>
              </h2>
              <p className="mt-xs text-body-sm text-muted">{t("invites.help")}</p>
              <ul className="mt-sm">
                {invites.map((inv) => (
                  <li
                    key={inv.id}
                    className="flex items-center gap-md border-t border-hairline py-md"
                  >
                    <span className="flex size-9 shrink-0 items-center justify-center rounded-full bg-surface-tint text-muted">
                      <Mail size={16} />
                    </span>
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-body-md text-ink">{inv.toEmail}</p>
                      <p className="truncate text-body-sm text-muted">
                        {inv.teamRoleName || t("role.staff")} · {summarise(inv.teamPermissions)}
                      </p>
                    </div>
                    <div className="flex shrink-0 items-center gap-xs">
                      <CopyInviteLink token={inv.token ?? null} />
                      <button
                        type="button"
                        disabled={busy || !canEdit}
                        onClick={() => run(() => cancelInvite(inv.id))}
                        title={canEdit ? undefined : lockTitle}
                        className="inline-flex h-9 items-center rounded-button px-md text-label-md text-muted transition-colors hover:text-error disabled:text-disabled disabled:hover:text-muted"
                      >
                        {t("invites.cancel")}
                      </button>
                    </div>
                  </li>
                ))}
              </ul>
            </>
          ) : null}

          {/* Roles */}
          <Divider className="my-xl" />
          <div className="flex items-center justify-between gap-md">
            <h2 className="text-title-md text-ink">
              {t("roles.title")} <span className="text-subtle">· {roles.length}</span>
            </h2>
            <button
              type="button"
              onClick={() => setRoleEditor("new")}
              className="inline-flex h-9 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint"
            >
              <Plus size={16} /> {t("roles.new")}
            </button>
          </div>
          <p className="mt-xs text-body-sm text-muted">{t("roles.help")}</p>
          <ul className="mt-sm">
            {roles.map((role) => (
              <li
                key={role.id}
                className="flex items-center gap-md border-t border-hairline py-md"
              >
                <span className="flex size-9 shrink-0 items-center justify-center rounded-full bg-surface-tint text-muted">
                  <ShieldCheck size={16} />
                </span>
                <div className="min-w-0 flex-1">
                  <p className="truncate text-body-md text-ink">
                    {role.name}
                    {role.builtin ? (
                      <span className="ml-sm rounded-full bg-surface-tint px-sm py-px text-body-sm text-muted">
                        {t("roles.builtin")}
                      </span>
                    ) : null}
                  </p>
                  <p className="truncate text-body-sm text-muted">
                    {summarise(role.permissions)}
                  </p>
                </div>
                <button
                  type="button"
                  onClick={() => setRoleEditor(role)}
                  disabled={!canEdit}
                  aria-label={t("roles.editAria")}
                  title={canEdit ? undefined : lockTitle}
                  className="rounded-md p-xs text-muted transition-colors hover:bg-surface-tint hover:text-ink disabled:text-disabled disabled:hover:bg-transparent"
                >
                  <Pencil size={16} />
                </button>
                <button
                  type="button"
                  disabled={busy || !canEdit}
                  onClick={() => run(() => deleteRole(role.id))}
                  aria-label={t("roles.deleteAria")}
                  title={canEdit ? undefined : lockTitle}
                  className="rounded-md p-xs text-muted transition-colors hover:bg-error-soft hover:text-error disabled:text-disabled disabled:hover:bg-transparent"
                >
                  <Trash2 size={16} />
                </button>
              </li>
            ))}
          </ul>
        </>
      )}

      {inviteOpen ? (
        <InviteModal
          roles={roles}
          busy={busy}
          onClose={() => setInviteOpen(false)}
          onSubmit={(input) =>
            run(async () => {
              await sendInvite(input);
              setInviteOpen(false);
            })
          }
        />
      ) : null}

      {editMember ? (
        <MemberModal
          member={editMember}
          busy={busy}
          onClose={() => setEditMember(null)}
          onSubmit={(roleName, permissions) =>
            run(async () => {
              await setMemberPermissions(editMember.user.id, { roleName, permissions });
              setEditMember(null);
            })
          }
        />
      ) : null}

      {roleEditor ? (
        <RoleModal
          role={roleEditor === "new" ? null : roleEditor}
          busy={busy}
          onClose={() => setRoleEditor(null)}
          onSubmit={(name, permissions) =>
            run(async () => {
              if (roleEditor === "new") await createRole({ name, permissions });
              else await updateRole(roleEditor.id, { name, permissions });
              setRoleEditor(null);
            })
          }
        />
      ) : null}
    </div>
  );
}

/** Copies a shareable `/accept-invite?token=…` URL for a pending invite.
 *  The link is the only delivery channel (there's no invite email), so this
 *  is how a brand-new hire reaches the correct onboarding screen instead of
 *  the "Set up your shop" register form. */
function CopyInviteLink({ token }: { token: string | null }) {
  const [copied, setCopied] = useState(false);
  const t = useTranslations("team");

  if (!token) return null;

  const onCopy = async () => {
    // Built from the current origin so it works in any environment.
    const url = `${window.location.origin}/accept-invite?token=${encodeURIComponent(token)}`;
    try {
      await navigator.clipboard.writeText(url);
      setCopied(true);
      window.setTimeout(() => setCopied(false), 2000);
    } catch {
      // Clipboard blocked (insecure context / permissions) — surface the
      // URL so the owner can copy it by hand rather than failing silently.
      window.prompt(t("invites.copyPrompt"), url);
    }
  };

  return (
    <button
      type="button"
      onClick={() => void onCopy()}
      title={t("invites.copyTitle")}
      className="inline-flex h-9 items-center gap-xs rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint"
    >
      {copied ? <Check size={15} className="text-success" /> : <Link2 size={15} />}
      {copied ? t("invites.copied") : t("invites.copyLink")}
    </button>
  );
}

function InviteModal({
  roles,
  busy,
  onClose,
  onSubmit,
}: {
  roles: Role[];
  busy: boolean;
  onClose: () => void;
  onSubmit: (input: {
    email: string;
    roleName: string;
    permissions: string[];
    message?: string;
  }) => void;
}) {
  const [email, setEmail] = useState("");
  const [roleName, setRoleName] = useState("");
  const [message, setMessage] = useState("");
  const [perms, setPerms] = useState<Set<string>>(new Set());
  const [custom, setCustom] = useState(false);
  const ceiling = useGrantCeiling();
  const t = useTranslations("team");

  function onPickRole(value: string) {
    if (value === "__custom__") {
      setCustom(true);
      setRoleName("");
      return;
    }
    setCustom(false);
    setRoleName(value);
    const role = roles.find((r) => r.name === value);
    if (role) setPerms(new Set(role.permissions));
  }

  return (
    <SideSheet title={t("invite.title")} onClose={onClose} side="right" width="w-[600px]">
      <label className="flex flex-col gap-xs">
        <span className="text-label-md text-muted">{t("invite.emailLabel")}</span>
        <input
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          autoFocus
          placeholder={t("invite.emailPlaceholder")}
          className="h-10 rounded-input border border-hairline bg-field px-md text-body-md text-ink outline-none focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft"
        />
      </label>
      <label className="flex flex-col gap-xs">
        <span className="text-label-md text-muted">{t("invite.roleLabel")}</span>
        <select
          value={custom ? "__custom__" : roleName}
          onChange={(e) => onPickRole(e.target.value)}
          className="h-10 rounded-input border border-hairline bg-field px-md text-body-md text-ink outline-none focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft"
        >
          <option value="" disabled>{t("invite.roleChoose")}</option>
          {roles.map((r) => (
            <option key={r.id} value={r.name}>{r.name}</option>
          ))}
          <option value="__custom__">{t("invite.roleCustom")}</option>
        </select>
        {custom ? (
          <input
            value={roleName}
            onChange={(e) => setRoleName(e.target.value)}
            placeholder={t("invite.customPlaceholder")}
            className="h-10 rounded-input border border-hairline bg-field px-md text-body-md text-ink outline-none focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft"
          />
        ) : null}
        <span className="text-body-sm text-subtle">{t("invite.roleHint")}</span>
      </label>
      <div className="flex flex-col gap-xs">
        <span className="text-label-md text-muted">{t("invite.accessLabel")}</span>
        <p className="rounded-md bg-surface-tint px-md py-sm text-body-sm text-muted">
          {t.rich("invite.accessHint", {
            b: (chunks) => <span className="font-semibold text-ink">{chunks}</span>,
          })}
        </p>
        <PermissionMatrix value={perms} onChange={setPerms} ceiling={ceiling} />
      </div>
      <label className="flex flex-col gap-xs">
        <span className="text-label-md text-muted">{t("invite.messageLabel")}</span>
        <textarea
          value={message}
          onChange={(e) => setMessage(e.target.value)}
          rows={2}
          maxLength={500}
          className="rounded-input border border-hairline bg-field px-md py-sm text-body-md text-ink outline-none focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft"
        />
      </label>
      <ModalActions
        busy={busy}
        disabled={!email.trim() || !roleName.trim() || perms.size === 0}
        confirmLabel={t("invite.submit")}
        onCancel={onClose}
        onConfirm={() =>
          onSubmit({
            email: email.trim(),
            roleName: roleName.trim(),
            permissions: normalizeRights(perms),
            message: message.trim() || undefined,
          })
        }
      />
    </SideSheet>
  );
}

function MemberModal({
  member,
  busy,
  onClose,
  onSubmit,
}: {
  member: Member;
  busy: boolean;
  onClose: () => void;
  onSubmit: (roleName: string, permissions: string[]) => void;
}) {
  const t = useTranslations("team");
  const [roleName, setRoleName] = useState(member.roleName ?? t("role.staff"));
  const [perms, setPerms] = useState<Set<string>>(new Set(member.permissions));
  const ceiling = useGrantCeiling();
  return (
    <Modal title={t("memberEdit.title", { name: member.user.name })} onClose={onClose} wide>
      <label className="flex flex-col gap-xs">
        <span className="text-label-md text-muted">{t("memberEdit.roleLabel")}</span>
        <input
          value={roleName}
          onChange={(e) => setRoleName(e.target.value)}
          className="h-10 rounded-input border border-hairline bg-field px-md text-body-md text-ink outline-none focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft"
        />
      </label>
      <div className="flex flex-col gap-xs">
        <span className="text-label-md text-muted">{t("memberEdit.accessLabel")}</span>
        <PermissionMatrix value={perms} onChange={setPerms} ceiling={ceiling} />
      </div>
      <ModalActions
        busy={busy}
        disabled={!roleName.trim() || perms.size === 0}
        confirmLabel={t("memberEdit.submit")}
        onCancel={onClose}
        onConfirm={() => onSubmit(roleName.trim(), normalizeRights(perms))}
      />
    </Modal>
  );
}

function RoleModal({
  role,
  busy,
  onClose,
  onSubmit,
}: {
  role: Role | null;
  busy: boolean;
  onClose: () => void;
  onSubmit: (name: string, permissions: string[]) => void;
}) {
  const t = useTranslations("team");
  const [name, setName] = useState(role?.name ?? "");
  const [perms, setPerms] = useState<Set<string>>(new Set(role?.permissions ?? []));
  const ceiling = useGrantCeiling();
  return (
    <Modal
      title={role ? t("roleEdit.editTitle", { name: role.name }) : t("roleEdit.newTitle")}
      onClose={onClose}
      wide
    >
      <label className="flex flex-col gap-xs">
        <span className="text-label-md text-muted">{t("roleEdit.nameLabel")}</span>
        <input
          value={name}
          onChange={(e) => setName(e.target.value)}
          autoFocus
          placeholder={t("roleEdit.namePlaceholder")}
          className="h-10 rounded-input border border-hairline bg-field px-md text-body-md text-ink outline-none focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft"
        />
      </label>
      <div className="flex flex-col gap-xs">
        <span className="text-label-md text-muted">{t("roleEdit.accessLabel")}</span>
        <PermissionMatrix value={perms} onChange={setPerms} ceiling={ceiling} />
      </div>
      <ModalActions
        busy={busy}
        disabled={!name.trim() || perms.size === 0}
        confirmLabel={role ? t("roleEdit.submitSave") : t("roleEdit.submitCreate")}
        onCancel={onClose}
        onConfirm={() => onSubmit(name.trim(), normalizeRights(perms))}
      />
    </Modal>
  );
}

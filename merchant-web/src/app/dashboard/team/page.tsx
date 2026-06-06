"use client";

import { useCallback, useEffect, useState } from "react";
import { Plus, Pencil, Trash2, Mail, ShieldCheck } from "lucide-react";
import { Divider } from "@/shared/ui/divider";
import { Modal, ModalActions } from "@/shared/ui/modal";
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
import { normalizeRights, summariseRights } from "@/features/team/permissions";
import { PermissionMatrix } from "@/features/team/permission-matrix";
import { useCanManage, useGrantCeiling } from "@/features/auth/use-can";
import { ListRowsSkeleton } from "@/shared/ui/skeleton";

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
  const lockTitle = "You don't have access. Ask the shop owner.";

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
        if (active) setError(e instanceof Error ? e.message : "Could not load the team.");
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [nonce]);

  async function run(fn: () => Promise<void>) {
    setBusy(true);
    setActionError(null);
    try {
      await fn();
      reload();
    } catch (e) {
      setActionError(e instanceof Error ? e.message : "Something went wrong.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <div className="flex flex-wrap items-start justify-between gap-md">
        <div>
          <h1 className="text-headline-md text-ink">Team</h1>
          <p className="mt-xs text-body-md text-muted">
            Invite staff and control exactly what each person can see and do.
          </p>
        </div>
        <button
          type="button"
          onClick={() => setInviteOpen(true)}
          className="inline-flex h-10 items-center gap-sm rounded-button bg-brand px-lg text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
        >
          <Plus size={18} /> Invite teammate
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
            Try again
          </button>
        </div>
      ) : (
        <>
          {/* Members */}
          <h2 className="mt-xl text-title-md text-ink">
            Members <span className="text-subtle">· {members.length}</span>
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
                    {m.isOwner ? "Owner" : m.roleName || "Staff"}
                  </p>
                  <p className="truncate text-body-sm text-muted">
                    {m.isOwner ? "Full access" : summariseRights(m.permissions)}
                  </p>
                </div>
                {m.isOwner ? (
                  <span className="rounded-full bg-brand-soft px-sm py-px text-body-sm text-brand-strong">
                    Owner
                  </span>
                ) : (
                  <div className="flex items-center gap-xs">
                    <button
                      type="button"
                      onClick={() => setEditMember(m)}
                      disabled={!canEdit}
                      aria-label="Edit permissions"
                      title={canEdit ? undefined : lockTitle}
                      className="rounded-md p-xs text-muted transition-colors hover:bg-surface-tint hover:text-ink disabled:text-disabled disabled:hover:bg-transparent"
                    >
                      <Pencil size={16} />
                    </button>
                    <button
                      type="button"
                      disabled={busy || !canEdit}
                      onClick={() => run(() => removeMember(m.user.id))}
                      aria-label="Remove member"
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
                Pending invites <span className="text-subtle">· {invites.length}</span>
              </h2>
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
                        {inv.teamRoleName || "Staff"} · {summariseRights(inv.teamPermissions)}
                      </p>
                    </div>
                    <button
                      type="button"
                      disabled={busy || !canEdit}
                      onClick={() => run(() => cancelInvite(inv.id))}
                      title={canEdit ? undefined : lockTitle}
                      className="inline-flex h-9 items-center rounded-button px-md text-label-md text-muted transition-colors hover:text-error disabled:text-disabled disabled:hover:text-muted"
                    >
                      Cancel
                    </button>
                  </li>
                ))}
              </ul>
            </>
          ) : null}

          {/* Roles */}
          <Divider className="my-xl" />
          <div className="flex items-center justify-between gap-md">
            <h2 className="text-title-md text-ink">
              Roles <span className="text-subtle">· {roles.length}</span>
            </h2>
            <button
              type="button"
              onClick={() => setRoleEditor("new")}
              className="inline-flex h-9 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint"
            >
              <Plus size={16} /> New role
            </button>
          </div>
          <p className="mt-xs text-body-sm text-muted">
            Reusable permission presets you can apply when inviting teammates.
          </p>
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
                        Built-in
                      </span>
                    ) : null}
                  </p>
                  <p className="truncate text-body-sm text-muted">
                    {summariseRights(role.permissions)}
                  </p>
                </div>
                <button
                  type="button"
                  onClick={() => setRoleEditor(role)}
                  disabled={!canEdit}
                  aria-label="Edit role"
                  title={canEdit ? undefined : lockTitle}
                  className="rounded-md p-xs text-muted transition-colors hover:bg-surface-tint hover:text-ink disabled:text-disabled disabled:hover:bg-transparent"
                >
                  <Pencil size={16} />
                </button>
                <button
                  type="button"
                  disabled={busy || !canEdit}
                  onClick={() => run(() => deleteRole(role.id))}
                  aria-label="Delete role"
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
  const ceiling = useGrantCeiling();

  function applyRole(name: string) {
    setRoleName(name);
    const role = roles.find((r) => r.name === name);
    if (role) setPerms(new Set(role.permissions));
  }

  return (
    <Modal title="Invite teammate" onClose={onClose} wide>
      <label className="flex flex-col gap-xs">
        <span className="text-label-md text-muted">Email</span>
        <input
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          autoFocus
          placeholder="teammate@example.com"
          className="h-10 rounded-input border border-hairline bg-white px-md text-body-md text-ink outline-none focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft"
        />
      </label>
      <label className="flex flex-col gap-xs">
        <span className="text-label-md text-muted">Role label</span>
        <input
          list="role-presets"
          value={roleName}
          onChange={(e) => applyRole(e.target.value)}
          placeholder="e.g. Cashier"
          className="h-10 rounded-input border border-hairline bg-white px-md text-body-md text-ink outline-none focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft"
        />
        <datalist id="role-presets">
          {roles.map((r) => (
            <option key={r.id} value={r.name} />
          ))}
        </datalist>
        <span className="text-body-sm text-subtle">
          Pick a saved role to prefill its access, then fine-tune below.
        </span>
      </label>
      <div className="flex flex-col gap-xs">
        <span className="text-label-md text-muted">Access</span>
        <PermissionMatrix value={perms} onChange={setPerms} ceiling={ceiling} />
      </div>
      <label className="flex flex-col gap-xs">
        <span className="text-label-md text-muted">Message (optional)</span>
        <textarea
          value={message}
          onChange={(e) => setMessage(e.target.value)}
          rows={2}
          maxLength={500}
          className="rounded-input border border-hairline bg-white px-md py-sm text-body-md text-ink outline-none focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft"
        />
      </label>
      <ModalActions
        busy={busy}
        disabled={!email.trim() || !roleName.trim() || perms.size === 0}
        confirmLabel="Send invite"
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
    </Modal>
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
  const [roleName, setRoleName] = useState(member.roleName ?? "Staff");
  const [perms, setPerms] = useState<Set<string>>(new Set(member.permissions));
  const ceiling = useGrantCeiling();
  return (
    <Modal title={`Edit ${member.user.name}`} onClose={onClose} wide>
      <label className="flex flex-col gap-xs">
        <span className="text-label-md text-muted">Role label</span>
        <input
          value={roleName}
          onChange={(e) => setRoleName(e.target.value)}
          className="h-10 rounded-input border border-hairline bg-white px-md text-body-md text-ink outline-none focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft"
        />
      </label>
      <div className="flex flex-col gap-xs">
        <span className="text-label-md text-muted">Access</span>
        <PermissionMatrix value={perms} onChange={setPerms} ceiling={ceiling} />
      </div>
      <ModalActions
        busy={busy}
        disabled={!roleName.trim() || perms.size === 0}
        confirmLabel="Save permissions"
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
  const [name, setName] = useState(role?.name ?? "");
  const [perms, setPerms] = useState<Set<string>>(new Set(role?.permissions ?? []));
  const ceiling = useGrantCeiling();
  return (
    <Modal title={role ? `Edit ${role.name}` : "New role"} onClose={onClose} wide>
      <label className="flex flex-col gap-xs">
        <span className="text-label-md text-muted">Role name</span>
        <input
          value={name}
          onChange={(e) => setName(e.target.value)}
          autoFocus
          placeholder="e.g. Floor staff"
          className="h-10 rounded-input border border-hairline bg-white px-md text-body-md text-ink outline-none focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft"
        />
      </label>
      <div className="flex flex-col gap-xs">
        <span className="text-label-md text-muted">Access</span>
        <PermissionMatrix value={perms} onChange={setPerms} ceiling={ceiling} />
      </div>
      <ModalActions
        busy={busy}
        disabled={!name.trim() || perms.size === 0}
        confirmLabel={role ? "Save role" : "Create role"}
        onCancel={onClose}
        onConfirm={() => onSubmit(name.trim(), normalizeRights(perms))}
      />
    </Modal>
  );
}

"use client";

import { useRef, useState, type ChangeEvent } from "react";
import { useTranslations } from "next-intl";
import { useAuth } from "../auth-context";
import { Avatar } from "./avatar";
import { Banner } from "./banner";

/** Profile-photo control: shows the current avatar with change / remove. */
export function AvatarPicker() {
  const { user, uploadAvatar, removeAvatar } = useAuth();
  const t = useTranslations("auth");
  const inputRef = useRef<HTMLInputElement>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function onFile(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    event.target.value = ""; // allow re-selecting the same file
    if (!file) return;
    setError(null);
    setBusy(true);
    try {
      await uploadAvatar(file);
    } catch (err) {
      setError(err instanceof Error ? err.message : t("avatar.uploadFailed"));
    } finally {
      setBusy(false);
    }
  }

  async function onRemove() {
    setError(null);
    setBusy(true);
    try {
      await removeAvatar();
    } catch (err) {
      setError(err instanceof Error ? err.message : t("avatar.removeFailed"));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="flex flex-col gap-md">
      <div className="flex items-center gap-lg">
        <Avatar url={user?.avatarUrl} name={user?.name ?? ""} size={64} />
        <div className="flex flex-col gap-sm">
          <div className="flex gap-md">
            <button
              type="button"
              onClick={() => inputRef.current?.click()}
              disabled={busy}
              className="inline-flex h-10 items-center justify-center rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:text-disabled"
            >
              {busy ? t("avatar.working") : t("avatar.changePhoto")}
            </button>
            {user?.avatarUrl ? (
              <button
                type="button"
                onClick={onRemove}
                disabled={busy}
                className="inline-flex h-10 items-center justify-center rounded-button px-md text-label-md text-muted transition-colors hover:text-ink focus-visible:outline-none disabled:text-disabled"
              >
                {t("avatar.remove")}
              </button>
            ) : null}
          </div>
          <p className="text-body-sm text-subtle">{t("avatar.formatHint")}</p>
        </div>
      </div>
      {error ? <Banner variant="error" message={error} /> : null}
      <input
        ref={inputRef}
        type="file"
        accept="image/png,image/jpeg,image/webp"
        className="hidden"
        onChange={onFile}
      />
    </div>
  );
}

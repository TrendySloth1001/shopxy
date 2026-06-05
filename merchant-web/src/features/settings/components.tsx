"use client";

import { useState } from "react";
import Link from "next/link";
import { ChevronRight, type LucideIcon } from "lucide-react";
import { useAuth } from "@/features/auth/auth-context";

/** Uppercase section label. */
export function Eyebrow({ children }: { children: React.ReactNode }) {
  return (
    <p className="px-sm pb-sm text-label-md uppercase tracking-wide text-subtle">
      {children}
    </p>
  );
}

/** Small muted pill — e.g. "Coming soon". */
export function ComingSoon() {
  return (
    <span className="rounded-full bg-hero-panel px-sm py-px text-label-md uppercase tracking-wide text-muted">
      Coming soon
    </span>
  );
}

type RowProps = {
  icon: LucideIcon;
  title: string;
  subtitle?: string;
  /** Renders as a link when set. */
  href?: string;
  /** Renders as a button when set (ignored if `href` is set). */
  onClick?: () => void;
  /** Replaces the default chevron (only shown for link/button rows). */
  trailing?: React.ReactNode;
  tone?: "default" | "error";
};

/** A flat settings row: icon puck + title/subtitle + trailing affordance. */
export function SettingRow({
  icon: Icon,
  title,
  subtitle,
  href,
  onClick,
  trailing,
  tone = "default",
}: RowProps) {
  const interactive = href != null || onClick != null;
  const titleColor = tone === "error" ? "text-error" : "text-ink";
  const iconColor = tone === "error" ? "text-error" : "text-ink";

  const inner = (
    <>
      <span
        className={`flex size-9 shrink-0 items-center justify-center rounded-md bg-hero-panel ${iconColor}`}
      >
        <Icon size={18} />
      </span>
      <span className="min-w-0 flex-1">
        <span className={`block text-body-md ${titleColor}`}>{title}</span>
        {subtitle ? (
          <span className="block truncate text-body-sm text-muted">{subtitle}</span>
        ) : null}
      </span>
      {interactive ? (
        trailing ?? <ChevronRight size={18} className="shrink-0 text-subtle" />
      ) : (
        trailing ?? null
      )}
    </>
  );

  const base =
    "flex w-full items-center gap-md rounded-md px-sm py-sm text-left transition-colors";

  if (href) {
    return (
      <Link
        href={href}
        className={`${base} hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft`}
      >
        {inner}
      </Link>
    );
  }
  if (onClick) {
    return (
      <button
        type="button"
        onClick={onClick}
        className={`${base} hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft`}
      >
        {inner}
      </button>
    );
  }
  return <div className={base}>{inner}</div>;
}

/** Pill toggle used for boolean settings. */
function Toggle({
  checked,
  disabled,
  onChange,
  label,
}: {
  checked: boolean;
  disabled?: boolean;
  onChange: () => void;
  label: string;
}) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      aria-label={label}
      disabled={disabled}
      onClick={onChange}
      className={`relative inline-flex h-6 w-10 shrink-0 items-center rounded-full transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:opacity-60 ${
        checked ? "bg-brand" : "bg-hairline"
      }`}
    >
      <span
        className={`inline-block size-5 rounded-full bg-white shadow-floating transition-transform ${
          checked ? "translate-x-[18px]" : "translate-x-px"
        }`}
      />
    </button>
  );
}

/** Email-notifications setting — persisted via `updateProfile`. */
export function NotificationsToggle({
  icon: Icon,
}: {
  icon: LucideIcon;
}) {
  const { user, updateProfile } = useAuth();
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const value = user?.emailNotifications ?? true;

  async function toggle() {
    if (saving) return;
    setSaving(true);
    setError(null);
    try {
      await updateProfile({ emailNotifications: !value });
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not save the preference.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="flex w-full items-center gap-md rounded-md px-sm py-sm">
      <span className="flex size-9 shrink-0 items-center justify-center rounded-md bg-hero-panel text-ink">
        <Icon size={18} />
      </span>
      <div className="min-w-0 flex-1">
        <p className="text-body-md text-ink">Email notifications</p>
        <p className="text-body-sm text-muted">
          {error ?? "Low-stock alerts and the weekly summary."}
        </p>
      </div>
      <Toggle
        checked={value}
        disabled={saving}
        onChange={toggle}
        label="Email notifications"
      />
    </div>
  );
}

"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import Link from "next/link";
import Image from "next/image";
import { BadgeCheck, Check, ChevronRight, ImagePlus, Trash2, Users, Wallet } from "lucide-react";
import { Divider } from "@/shared/ui/divider";
import { mediaSrc } from "@/features/products/components/product-thumb";
import {
  getShop,
  setShopPublished,
  updateShop,
  uploadShopImage,
  type ShopUpdate,
} from "@/features/shop/api";
import { DAYS, DAY_LABELS, type Day, type Shop } from "@/features/shop/schema";
import { CardsSkeleton } from "@/shared/ui/skeleton";

type DayHours = { open: boolean; from: string; to: string };

function initHours(shop: Shop): Record<Day, DayHours> {
  const out = {} as Record<Day, DayHours>;
  for (const d of DAYS) {
    const t = shop.operatingHours?.[d];
    out[d] = t
      ? { open: true, from: t[0], to: t[1] }
      : { open: false, from: "09:00", to: "18:00" };
  }
  return out;
}

export default function ShopPage() {
  const [shop, setShop] = useState<Shop | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [nonce, setNonce] = useState(0);

  const [form, setForm] = useState<{
    name: string;
    tagline: string;
    locationCity: string;
    locationState: string;
    logoUrl: string | null;
    bannerUrl: string | null;
    vacationMode: boolean;
    vacationMessage: string;
    returnPolicy: string;
    shippingPolicy: string;
    refundPolicy: string;
    hours: Record<Day, DayHours>;
  } | null>(null);

  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);
  const [publishing, setPublishing] = useState(false);

  const reload = useCallback(() => setNonce((n) => n + 1), []);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const s = await getShop();
        if (!active) return;
        setShop(s);
        setForm({
          name: s.name ?? "",
          tagline: s.tagline ?? "",
          locationCity: s.locationCity ?? "",
          locationState: s.locationState ?? "",
          logoUrl: s.logoUrl ?? null,
          bannerUrl: s.bannerUrl ?? null,
          vacationMode: s.vacationMode,
          vacationMessage: s.vacationMessage ?? "",
          returnPolicy: s.returnPolicy ?? "",
          shippingPolicy: s.shippingPolicy ?? "",
          refundPolicy: s.refundPolicy ?? "",
          hours: initHours(s),
        });
        setError(null);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : "Could not load your shop.");
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [nonce]);

  function patch(p: Partial<NonNullable<typeof form>>) {
    setForm((f) => (f ? { ...f, ...p } : f));
    setSaved(false);
  }

  async function onTogglePublish() {
    if (!shop) return;
    setPublishing(true);
    setActionError(null);
    try {
      const updated = await setShopPublished(!shop.isPublished);
      setShop(updated);
    } catch (e) {
      setActionError(e instanceof Error ? e.message : "Could not update publish state.");
    } finally {
      setPublishing(false);
    }
  }

  async function onSave() {
    if (!form) return;
    setSaving(true);
    setSaved(false);
    setActionError(null);
    const operatingHours: Record<string, [string, string]> = {};
    for (const d of DAYS) {
      const h = form.hours[d];
      if (h.open) operatingHours[d] = [h.from, h.to];
    }
    const payload: ShopUpdate = {
      name: form.name.trim() || undefined,
      tagline: form.tagline.trim() || null,
      logoUrl: form.logoUrl,
      bannerUrl: form.bannerUrl,
      locationCity: form.locationCity.trim() || null,
      locationState: form.locationState.trim() || null,
      returnPolicy: form.returnPolicy.trim() || null,
      shippingPolicy: form.shippingPolicy.trim() || null,
      refundPolicy: form.refundPolicy.trim() || null,
      vacationMode: form.vacationMode,
      vacationMessage: form.vacationMessage.trim() || null,
      operatingHours,
    };
    try {
      const updated = await updateShop(payload);
      setShop(updated);
      setSaved(true);
    } catch (e) {
      setActionError(e instanceof Error ? e.message : "Could not save your shop.");
    } finally {
      setSaving(false);
    }
  }

  if (loading) {
    return (
      <div className="w-full px-lg py-xxl md:px-xxl">
        <CardsSkeleton count={3} />
      </div>
    );
  }
  if (error || !shop || !form) {
    return (
      <div className="w-full px-lg py-xxl md:px-xxl">
        <div className="flex flex-col items-start gap-md py-xxl">
          <p className="text-body-md text-muted">{error ?? "Could not load your shop."}</p>
          <button
            type="button"
            onClick={reload}
            className="inline-flex h-10 items-center rounded-button border border-hairline px-lg text-label-md text-ink transition-colors hover:bg-surface-tint"
          >
            Try again
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="w-full px-lg py-xxl pb-massive md:px-xxl">
      <div className="flex flex-wrap items-start justify-between gap-md">
        <div>
          <div className="flex flex-wrap items-center gap-sm">
            <h1 className="text-headline-md text-ink">My shop</h1>
            {shop.isVerified ? (
              <span className="inline-flex items-center gap-xs rounded-full border border-success bg-white px-sm py-px text-body-sm font-bold text-success">
                <BadgeCheck size={14} /> Verified
              </span>
            ) : null}
          </div>
          <p className="mt-xs text-body-md text-muted">
            Your public storefront, hours and policies.
            {shop.slug ? ` Customers find you at /shops/${shop.slug}.` : ""}
          </p>
        </div>
        <button
          type="button"
          onClick={onTogglePublish}
          disabled={publishing}
          className={`inline-flex h-10 items-center gap-sm rounded-button px-md text-label-md transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:text-disabled ${
            shop.isPublished
              ? "bg-brand-soft text-brand-strong"
              : "border border-hairline text-ink hover:bg-surface-tint"
          }`}
        >
          {shop.isPublished ? "Published" : "Publish shop"}
        </button>
      </div>

      {actionError ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">
          {actionError}
        </p>
      ) : null}
      {saved ? (
        <p className="mt-md flex items-center gap-sm rounded-md bg-success-soft px-md py-sm text-body-sm text-success">
          <Check size={16} /> Shop saved.
        </p>
      ) : null}

      {/* Storefront */}
      <SectionTitle title="Storefront" desc="Logo, banner and how you appear to customers." />
      <div className="max-w-content">
        <ImageField
          label="Banner"
          aspect="aspect-[3/1]"
          url={form.bannerUrl}
          onChange={(url) => patch({ bannerUrl: url })}
        />
        <div className="mt-lg">
          <ImageField
            label="Logo"
            aspect="size-24"
            rounded
            url={form.logoUrl}
            onChange={(url) => patch({ logoUrl: url })}
          />
        </div>
        <div className="mt-lg flex flex-col gap-lg">
          <TextInput label="Shop name" value={form.name} onChange={(v) => patch({ name: v })} />
          <TextInput
            label="Tagline"
            value={form.tagline}
            onChange={(v) => patch({ tagline: v })}
            placeholder="A short line shown under your name"
          />
          <div className="grid grid-cols-2 gap-lg">
            <TextInput
              label="City"
              value={form.locationCity}
              onChange={(v) => patch({ locationCity: v })}
            />
            <TextInput
              label="State"
              value={form.locationState}
              onChange={(v) => patch({ locationState: v })}
            />
          </div>
        </div>
      </div>

      {/* Vacation mode */}
      <SectionTitle title="Vacation mode" desc="Pause new orders and show customers a note." />
      <div className="max-w-content">
        <ToggleRow
          label="Vacation mode"
          desc="When on, your storefront shows you're away."
          checked={form.vacationMode}
          onChange={() => patch({ vacationMode: !form.vacationMode })}
        />
        {form.vacationMode ? (
          <div className="mt-md">
            <TextInput
              label="Away message"
              value={form.vacationMessage}
              onChange={(v) => patch({ vacationMessage: v })}
              placeholder="Back on Monday — orders paused until then."
            />
          </div>
        ) : null}
      </div>

      {/* Operating hours */}
      <SectionTitle title="Operating hours" desc="Days you're open and your trading times." />
      <div className="max-w-content">
        {DAYS.map((d) => (
          <HoursRow
            key={d}
            label={DAY_LABELS[d]}
            value={form.hours[d]}
            onChange={(h) => patch({ hours: { ...form.hours, [d]: h } })}
          />
        ))}
      </div>

      {/* Policies */}
      <SectionTitle title="Policies" desc="Shown on your storefront and order pages." />
      <div className="max-w-content flex flex-col gap-lg">
        <TextArea
          label="Return policy"
          value={form.returnPolicy}
          onChange={(v) => patch({ returnPolicy: v })}
        />
        <TextArea
          label="Shipping policy"
          value={form.shippingPolicy}
          onChange={(v) => patch({ shippingPolicy: v })}
        />
        <TextArea
          label="Refund policy"
          value={form.refundPolicy}
          onChange={(v) => patch({ refundPolicy: v })}
        />
      </div>

      {/* More */}
      <SectionTitle title="More" desc="Team access and payouts." />
      <div className="max-w-content">
        <LinkRow icon={Users} title="Team" subtitle="Invite staff and set permissions" href="/dashboard/team" />
        <LinkRow icon={Wallet} title="Payouts" subtitle="Bank settlement & KYC" href="/dashboard/payouts" />
      </div>

      {/* Sticky save */}
      <div className="sticky bottom-0 mt-xxl -mx-lg border-t border-hairline bg-canvas px-lg py-md md:-mx-xxl md:px-xxl">
        <button
          type="button"
          onClick={onSave}
          disabled={saving}
          className="inline-flex h-11 items-center gap-sm rounded-button bg-brand px-xl text-label-lg text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:bg-disabled"
        >
          {saving ? "Saving…" : "Save changes"}
        </button>
      </div>
    </div>
  );
}

function SectionTitle({ title, desc }: { title: string; desc: string }) {
  return (
    <>
      <Divider className="my-xl" />
      <div className="mb-md">
        <h2 className="text-title-md text-ink">{title}</h2>
        <p className="mt-xs text-body-sm text-muted">{desc}</p>
      </div>
    </>
  );
}

function TextInput({
  label,
  value,
  onChange,
  placeholder,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
}) {
  return (
    <label className="flex flex-col gap-xs">
      <span className="text-label-md text-muted">{label}</span>
      <input
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        className="h-10 rounded-input border border-hairline bg-white px-md text-body-md text-ink outline-none placeholder:text-subtle focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft"
      />
    </label>
  );
}

function TextArea({
  label,
  value,
  onChange,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
}) {
  return (
    <label className="flex flex-col gap-xs">
      <span className="text-label-md text-muted">{label}</span>
      <textarea
        value={value}
        onChange={(e) => onChange(e.target.value)}
        rows={3}
        className="rounded-input border border-hairline bg-white px-md py-sm text-body-md text-ink outline-none focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft"
      />
    </label>
  );
}

function ToggleRow({
  label,
  desc,
  checked,
  onChange,
}: {
  label: string;
  desc: string;
  checked: boolean;
  onChange: () => void;
}) {
  return (
    <div className="flex items-center gap-md">
      <div className="min-w-0 flex-1">
        <p className="text-body-md text-ink">{label}</p>
        <p className="text-body-sm text-muted">{desc}</p>
      </div>
      <button
        type="button"
        role="switch"
        aria-checked={checked}
        aria-label={label}
        onClick={onChange}
        className={`relative inline-flex h-6 w-10 shrink-0 items-center rounded-full transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft ${
          checked ? "bg-brand" : "bg-hairline"
        }`}
      >
        <span
          className={`inline-block size-5 rounded-full bg-white shadow-floating transition-transform ${
            checked ? "translate-x-[18px]" : "translate-x-px"
          }`}
        />
      </button>
    </div>
  );
}

function HoursRow({
  label,
  value,
  onChange,
}: {
  label: string;
  value: DayHours;
  onChange: (h: DayHours) => void;
}) {
  return (
    <div className="flex flex-wrap items-center gap-md border-t border-hairline py-sm">
      <label className="flex w-32 items-center gap-sm">
        <input
          type="checkbox"
          checked={value.open}
          onChange={() => onChange({ ...value, open: !value.open })}
          className="size-4 cursor-pointer accent-brand"
        />
        <span className="text-body-md text-ink">{label}</span>
      </label>
      {value.open ? (
        <div className="flex items-center gap-sm">
          <input
            type="time"
            value={value.from}
            onChange={(e) => onChange({ ...value, from: e.target.value })}
            className="h-9 rounded-input border border-hairline bg-white px-md text-body-md text-ink outline-none focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft"
          />
          <span className="text-body-sm text-muted">to</span>
          <input
            type="time"
            value={value.to}
            onChange={(e) => onChange({ ...value, to: e.target.value })}
            className="h-9 rounded-input border border-hairline bg-white px-md text-body-md text-ink outline-none focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft"
          />
        </div>
      ) : (
        <span className="text-body-sm text-subtle">Closed</span>
      )}
    </div>
  );
}

function LinkRow({
  icon: Icon,
  title,
  subtitle,
  href,
}: {
  icon: typeof Users;
  title: string;
  subtitle: string;
  href: string;
}) {
  return (
    <Link
      href={href}
      className="flex items-center gap-md rounded-md border-t border-hairline py-md transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
    >
      <span className="flex size-9 shrink-0 items-center justify-center rounded-md bg-hero-panel text-ink">
        <Icon size={18} />
      </span>
      <span className="min-w-0 flex-1">
        <span className="block text-body-md text-ink">{title}</span>
        <span className="block text-body-sm text-muted">{subtitle}</span>
      </span>
      <ChevronRight size={18} className="text-subtle" />
    </Link>
  );
}

function ImageField({
  label,
  url,
  aspect,
  rounded,
  onChange,
}: {
  label: string;
  url: string | null;
  aspect: string;
  rounded?: boolean;
  onChange: (url: string | null) => void;
}) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [uploading, setUploading] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const src = mediaSrc(url);

  async function onPick(file: File) {
    setUploading(true);
    setErr(null);
    try {
      const stored = await uploadShopImage(file);
      onChange(stored);
    } catch (e) {
      setErr(e instanceof Error ? e.message : "Upload failed.");
    } finally {
      setUploading(false);
    }
  }

  return (
    <div className="flex flex-col gap-xs">
      <span className="text-label-md text-muted">{label}</span>
      <div className="flex items-center gap-md">
        <div
          className={`relative overflow-hidden border border-hairline bg-surface-tint ${aspect} ${
            rounded ? "rounded-full" : "w-full max-w-md rounded-lg"
          }`}
        >
          {src ? (
            <Image src={src} alt={label} fill unoptimized className="object-cover" sizes="384px" />
          ) : (
            <span className="flex size-full items-center justify-center text-subtle">
              <ImagePlus size={20} />
            </span>
          )}
        </div>
        <div className="flex flex-col gap-sm">
          <input
            ref={inputRef}
            type="file"
            accept="image/*"
            hidden
            onChange={(e) => {
              const f = e.target.files?.[0];
              if (f) void onPick(f);
              e.target.value = "";
            }}
          />
          <button
            type="button"
            onClick={() => inputRef.current?.click()}
            disabled={uploading}
            className="inline-flex h-9 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint disabled:text-disabled"
          >
            <ImagePlus size={16} /> {uploading ? "Uploading…" : url ? "Replace" : "Upload"}
          </button>
          {url ? (
            <button
              type="button"
              onClick={() => onChange(null)}
              className="inline-flex h-9 items-center gap-sm rounded-button px-md text-label-md text-muted transition-colors hover:text-error"
            >
              <Trash2 size={16} /> Remove
            </button>
          ) : null}
          {err ? <span className="text-body-sm text-error">{err}</span> : null}
        </div>
      </div>
    </div>
  );
}

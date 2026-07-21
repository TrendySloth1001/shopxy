"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import Link from "next/link";
import Image from "next/image";
import { useTranslations } from "next-intl";
import { BadgeCheck, Check, ChevronRight, ImagePlus, Plane, Star, Trash2, Users, Wallet } from "lucide-react";
import { mediaSrc } from "@/features/products/components/product-thumb";
import {
  getShop,
  setShopPublished,
  updateShop,
  uploadShopImage,
  type ShopUpdate,
} from "@/features/shop/api";
import {
  CANCELLATION_POLICIES,
  DAYS,
  REFUND_MODES_SELECTABLE,
  returnWindowDaysSchema,
  type CancellationPolicy,
  type Day,
  type RefundMode,
  type Shop,
} from "@/features/shop/schema";
import { CardsSkeleton } from "@/shared/ui/skeleton";
import { ComboSelect } from "@/shared/ui/combo-select";
import { TimeSelect } from "@/shared/ui/date-picker";

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
  const t = useTranslations("shop");
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
    returnsEnabled: boolean;
    returnWindowDays: string;
    refundMode: RefundMode;
    returnPolicyNote: string;
    cancellationPolicy: CancellationPolicy;
    hours: Record<Day, DayHours>;
  } | null>(null);

  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);
  const [publishing, setPublishing] = useState(false);
  const [tab, setTab] = useState<TabKey>("storefront");

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
          returnsEnabled: s.returnsEnabled,
          returnWindowDays: String(s.returnWindowDays),
          refundMode: s.refundMode,
          returnPolicyNote: s.returnPolicyNote ?? "",
          cancellationPolicy: s.cancellationPolicy,
          hours: initHours(s),
        });
        setError(null);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : t("errors.load"));
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [nonce, t]);

  function patch(p: Partial<NonNullable<typeof form>>) {
    setForm((f) => (f ? { ...f, ...p } : f));
    setSaved(false);
  }

  // Logo/banner persist immediately (a single-field save) so an uploaded image
  // survives a reload without depending on the main Save bar or other fields.
  async function saveImage(field: "logoUrl" | "bannerUrl", url: string | null) {
    patch({ [field]: url });
    setActionError(null);
    try {
      const updated = await updateShop({ [field]: url });
      setShop(updated);
    } catch (e) {
      setActionError(e instanceof Error ? e.message : t("errors.saveImage"));
    }
  }

  async function onTogglePublish() {
    if (!shop) return;
    setPublishing(true);
    setActionError(null);
    try {
      const updated = await setShopPublished(!shop.isPublished);
      setShop(updated);
    } catch (e) {
      setActionError(e instanceof Error ? e.message : t("errors.publish"));
    } finally {
      setPublishing(false);
    }
  }

  async function onSave() {
    if (!form) return;
    const windowDays = returnWindowDaysSchema.safeParse(form.returnWindowDays.trim() || undefined);
    if (!windowDays.success) {
      setActionError(t("errors.returnWindow"));
      return;
    }
    if (form.returnPolicyNote.length > 2048) {
      setActionError(t("errors.returnNoteLength"));
      return;
    }
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
      returnsEnabled: form.returnsEnabled,
      returnWindowDays: windowDays.data,
      refundMode: form.refundMode,
      returnPolicyNote: form.returnPolicyNote.trim() || null,
      cancellationPolicy: form.cancellationPolicy,
      operatingHours,
    };
    try {
      const updated = await updateShop(payload);
      setShop(updated);
      setSaved(true);
    } catch (e) {
      setActionError(e instanceof Error ? e.message : t("errors.save"));
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
          <p className="text-body-md text-muted">{error ?? t("errors.load")}</p>
          <button
            type="button"
            onClick={reload}
            className="inline-flex h-10 items-center rounded-button border border-hairline px-lg text-label-md text-ink transition-colors hover:bg-surface-tint"
          >
            {t("actions.tryAgain")}
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="w-full px-lg py-xxl pb-massive md:px-xxl">
      {/* Storefront preview hero — how customers see you, live as you edit. */}
      <ShopHero
        shop={shop}
        name={form.name}
        tagline={form.tagline}
        city={form.locationCity}
        state={form.locationState}
        logoUrl={form.logoUrl}
        bannerUrl={form.bannerUrl}
        vacationMode={form.vacationMode}
        vacationMessage={form.vacationMessage}
        publishing={publishing}
        onTogglePublish={onTogglePublish}
      />

      {/* Section tabs */}
      <div className="mt-xl overflow-x-auto">
        <div role="tablist" aria-label={t("tabs.ariaLabel")} className="inline-flex gap-xs border-b border-hairline">
          {TABS.map((item) => {
            const selected = tab === item.key;
            return (
              <button
                key={item.key}
                type="button"
                role="tab"
                aria-selected={selected}
                onClick={() => setTab(item.key)}
                className={`-mb-px whitespace-nowrap border-b-2 px-md py-sm text-label-md transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft ${
                  selected
                    ? "border-brand text-brand-strong"
                    : "border-transparent text-muted hover:text-ink"
                }`}
              >
                {t(`tabs.${item.key}`)}
              </button>
            );
          })}
        </div>
      </div>

      {actionError ? (
        <p className="mt-lg rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{actionError}</p>
      ) : null}
      {saved ? (
        <p className="mt-lg flex items-center gap-sm rounded-md bg-success-soft px-md py-sm text-body-sm text-success">
          <Check size={16} /> {t("savedMessage")}
        </p>
      ) : null}

      <div className="mt-xl">
        {tab === "storefront" ? (
          <div className="grid items-start gap-xl lg:grid-cols-3">
            <Card
              title={t("branding.title")}
              desc={t("branding.desc")}
              className="lg:col-span-2"
            >
              <div className="grid items-start gap-lg md:grid-cols-2">
                <div className="flex flex-col gap-lg">
                  <ImageField label={t("branding.banner")} aspect="aspect-[3/1]" url={form.bannerUrl} onChange={(url) => saveImage("bannerUrl", url)} />
                  <ImageField label={t("branding.logo")} aspect="size-24" rounded url={form.logoUrl} onChange={(url) => saveImage("logoUrl", url)} />
                </div>
                <div className="flex flex-col gap-lg">
                  <TextInput label={t("branding.shopName")} value={form.name} onChange={(v) => patch({ name: v })} />
                  <TextInput label={t("branding.tagline")} value={form.tagline} onChange={(v) => patch({ tagline: v })} placeholder={t("branding.taglinePlaceholder")} />
                  <div className="grid grid-cols-2 gap-lg">
                    <TextInput label={t("branding.city")} value={form.locationCity} onChange={(v) => patch({ locationCity: v })} />
                    <TextInput label={t("branding.state")} value={form.locationState} onChange={(v) => patch({ locationState: v })} />
                  </div>
                </div>
              </div>
            </Card>

            <Card title={t("vacation.title")} desc={t("vacation.desc")}>
              <ToggleRow
                label={t("vacation.toggleLabel")}
                desc={t("vacation.toggleDesc")}
                checked={form.vacationMode}
                onChange={() => patch({ vacationMode: !form.vacationMode })}
              />
              {form.vacationMode ? (
                <div className="mt-md">
                  <TextInput
                    label={t("vacation.messageLabel")}
                    value={form.vacationMessage}
                    onChange={(v) => patch({ vacationMessage: v })}
                    placeholder={t("vacation.messagePlaceholder")}
                  />
                </div>
              ) : null}
            </Card>
          </div>
        ) : null}

        {tab === "hours" ? (
          <Card title={t("hours.title")} desc={t("hours.desc")}>
            <div className="grid gap-x-xxl sm:grid-cols-2 xl:grid-cols-3">
              {DAYS.map((d) => (
                <HoursRow key={d} label={t(`days.${d}`)} value={form.hours[d]} onChange={(h) => patch({ hours: { ...form.hours, [d]: h } })} />
              ))}
            </div>
          </Card>
        ) : null}

        {tab === "policies" ? (
          <Card title={t("policies.title")} desc={t("policies.desc")}>
            <div className="grid gap-lg md:grid-cols-2 xl:grid-cols-3">
              <TextArea label={t("policies.returnPolicy")} value={form.returnPolicy} onChange={(v) => patch({ returnPolicy: v })} />
              <TextArea label={t("policies.shippingPolicy")} value={form.shippingPolicy} onChange={(v) => patch({ shippingPolicy: v })} />
              <TextArea label={t("policies.refundPolicy")} value={form.refundPolicy} onChange={(v) => patch({ refundPolicy: v })} />
            </div>
          </Card>
        ) : null}

        {tab === "returns" ? (
          <Card
            title={t("returns.title")}
            desc={t("returns.desc")}
          >
            <div className="flex flex-col gap-lg">
              <ToggleRow
                label={t("returns.acceptLabel")}
                desc={t("returns.acceptDesc")}
                checked={form.returnsEnabled}
                onChange={() => patch({ returnsEnabled: !form.returnsEnabled })}
              />
              {form.returnsEnabled ? (
                <>
                  <div className="grid grid-cols-1 gap-lg sm:grid-cols-2">
                    <label className="flex flex-col gap-xs">
                      <span className="text-label-md text-muted">{t("returns.windowLabel")}</span>
                      <input
                        type="number"
                        min={0}
                        max={365}
                        step={1}
                        inputMode="numeric"
                        value={form.returnWindowDays}
                        onChange={(e) => patch({ returnWindowDays: e.target.value })}
                        className="h-10 rounded-input border border-hairline bg-field px-md text-body-md text-ink outline-none focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft"
                      />
                      <span className="text-body-sm text-subtle">{t("returns.windowHint")}</span>
                    </label>
                    <SelectField
                      label={t("returns.refundMethodLabel")}
                      value={form.refundMode}
                      options={REFUND_MODES_SELECTABLE.map((m) => ({ value: m, label: t(`refundModes.${m}`) }))}
                      onChange={(v) => patch({ refundMode: v })}
                    />
                  </div>
                  <label className="flex flex-col gap-xs">
                    <span className="text-label-md text-muted">{t("returns.noteLabel")}</span>
                    <textarea
                      value={form.returnPolicyNote}
                      onChange={(e) => patch({ returnPolicyNote: e.target.value })}
                      rows={3}
                      maxLength={2048}
                      placeholder={t("returns.notePlaceholder")}
                      className="rounded-input border border-hairline bg-field px-md py-sm text-body-md text-ink outline-none placeholder:text-subtle focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft"
                    />
                  </label>
                </>
              ) : null}
              <div className="grid grid-cols-1 gap-lg sm:grid-cols-2">
                <SelectField
                  label={t("returns.cancelLabel")}
                  value={form.cancellationPolicy}
                  options={CANCELLATION_POLICIES.map((p) => ({ value: p, label: t(`cancellationPolicies.${p}`) }))}
                  onChange={(v) => patch({ cancellationPolicy: v })}
                  hint={t("returns.cancelHint")}
                />
              </div>
            </div>
          </Card>
        ) : null}

        {tab === "more" ? (
          <Card title={t("more.title")} desc={t("more.desc")}>
            <div className="grid gap-md sm:grid-cols-2">
              <LinkRow icon={Users} title={t("more.teamTitle")} subtitle={t("more.teamSubtitle")} href="/dashboard/team" />
              <LinkRow icon={Wallet} title={t("more.payoutsTitle")} subtitle={t("more.payoutsSubtitle")} href="/dashboard/payouts" />
            </div>
          </Card>
        ) : null}
      </div>

      {/* Sticky save — hidden on the link-only "More" tab. */}
      {tab !== "more" ? (
        <div className="sticky bottom-0 mt-xxl -mx-lg border-t border-hairline bg-canvas px-lg py-md md:-mx-xxl md:px-xxl">
          <button
            type="button"
            onClick={onSave}
            disabled={saving}
            className="inline-flex h-11 items-center gap-sm rounded-button bg-brand px-xl text-label-lg text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:bg-disabled"
          >
            {saving ? t("actions.saving") : t("actions.save")}
          </button>
        </div>
      ) : null}
    </div>
  );
}

type TabKey = "storefront" | "hours" | "policies" | "returns" | "more";
const TABS: { key: TabKey }[] = [
  { key: "storefront" },
  { key: "hours" },
  { key: "policies" },
  { key: "returns" },
  { key: "more" },
];

/** Card shell for a settings section. */
function Card({
  title,
  desc,
  children,
  className,
}: {
  title: string;
  desc: string;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <section className={`rounded-xl border border-hairline bg-canvas p-lg ${className ?? ""}`}>
      <h2 className="text-title-md text-ink">{title}</h2>
      <p className="mt-xs text-body-sm text-muted">{desc}</p>
      <div className="mt-lg">{children}</div>
    </section>
  );
}

/** Live storefront-preview hero: banner + logo + identity + publish control. */
function ShopHero({
  shop,
  name,
  tagline,
  city,
  state,
  logoUrl,
  bannerUrl,
  vacationMode,
  vacationMessage,
  publishing,
  onTogglePublish,
}: {
  shop: Shop;
  name: string;
  tagline: string;
  city: string;
  state: string;
  logoUrl: string | null;
  bannerUrl: string | null;
  vacationMode: boolean;
  vacationMessage: string;
  publishing: boolean;
  onTogglePublish: () => void;
}) {
  const t = useTranslations("shop");
  const location = [city, state].filter(Boolean).join(", ");
  const rating = shop.rating != null ? Number(shop.rating) : null;
  const banner = bannerUrl ? mediaSrc(bannerUrl) : null;
  const logo = logoUrl ? mediaSrc(logoUrl) : null;
  return (
    <section className="overflow-hidden rounded-xl border border-hairline bg-canvas">
      <div className="relative aspect-[5/1] w-full bg-surface-tint">
        {banner ? <Image src={banner} alt="" fill className="object-cover" sizes="100vw" unoptimized /> : null}
      </div>
      <div className="px-lg pb-lg">
        {/* Logo overlaps the banner; identity sits below it, left-aligned.
            relative z-10 keeps it above the `relative` banner (which would
            otherwise paint over the overlapping top of the logo). */}
        <div className="relative z-10 -mt-10 size-20 overflow-hidden rounded-xl border-4 border-canvas bg-surface-tint shadow-snackbar">
          {logo ? (
            <Image src={logo} alt="" width={80} height={80} className="size-full object-cover" unoptimized />
          ) : (
            <span className="flex size-full items-center justify-center text-headline-sm text-subtle">
              {(name || "S").charAt(0).toUpperCase()}
            </span>
          )}
        </div>

        <div className="mt-md flex flex-wrap items-start justify-between gap-md">
          <div className="min-w-0">
            <div className="flex flex-wrap items-center gap-sm">
              <h1 className="truncate text-headline-sm text-ink">{name || t("hero.fallbackName")}</h1>
              {shop.isVerified ? (
                <span className="inline-flex items-center gap-xs rounded-full bg-success-soft px-sm py-px text-label-md text-success">
                  <BadgeCheck size={13} /> {t("hero.verified")}
                </span>
              ) : null}
              <span
                className={`inline-flex items-center rounded-full px-sm py-px text-label-md ${
                  shop.isPublished ? "bg-brand-soft text-brand-strong" : "bg-surface-tint text-muted"
                }`}
              >
                {shop.isPublished ? t("hero.live") : t("hero.draft")}
              </span>
            </div>
            {tagline ? <p className="mt-xs truncate text-body-sm text-muted">{tagline}</p> : null}
            <p className="mt-xs flex flex-wrap items-center gap-x-md gap-y-xs text-body-sm text-subtle">
              {location ? <span>{location}</span> : null}
              {rating != null && shop.ratingCount > 0 ? (
                <span className="inline-flex items-center gap-xs">
                  <Star size={12} className="text-accent-amber" /> {rating.toFixed(1)} ({shop.ratingCount})
                </span>
              ) : null}
              {shop.slug ? <span className="truncate">/shops/{shop.slug}</span> : null}
            </p>
          </div>
          <button
            type="button"
            onClick={onTogglePublish}
            disabled={publishing}
            className={`inline-flex h-10 shrink-0 items-center gap-sm rounded-button px-md text-label-md transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:opacity-60 ${
              shop.isPublished
                ? "border border-hairline text-ink hover:bg-surface-tint"
                : "bg-brand text-white hover:bg-brand-strong"
            }`}
          >
            {publishing ? "…" : shop.isPublished ? t("hero.unpublish") : t("hero.publish")}
          </button>
        </div>

        {vacationMode ? (
          <p className="mt-md flex items-center gap-sm rounded-md bg-accent-amber-soft px-md py-sm text-body-sm text-accent-amber">
            <Plane size={15} /> {t("hero.onVacation")}{vacationMessage ? ` — ${vacationMessage}` : t("hero.vacationPaused")}
          </p>
        ) : null}
      </div>
    </section>
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
        className="h-10 rounded-input border border-hairline bg-field px-md text-body-md text-ink outline-none placeholder:text-subtle focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft"
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
        className="rounded-input border border-hairline bg-field px-md py-sm text-body-md text-ink outline-none focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft"
      />
    </label>
  );
}

function SelectField<T extends string>({
  label,
  value,
  options,
  onChange,
  hint,
}: {
  label: string;
  value: T;
  options: { value: T; label: string }[];
  onChange: (v: T) => void;
  hint?: string;
}) {
  return (
    <ComboSelect
      label={label}
      value={value}
      onChange={(v) => onChange(v as T)}
      options={options}
      helper={hint}
      className="w-full"
    />
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
          className={`inline-block size-5 rounded-full bg-surface shadow-floating transition-transform ${
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
  const t = useTranslations("shop");
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
          <TimeSelect
            value={value.from}
            onChange={(tm) => onChange({ ...value, from: tm })}
          />
          <span className="text-body-sm text-muted">{t("hours.to")}</span>
          <TimeSelect
            value={value.to}
            onChange={(tm) => onChange({ ...value, to: tm })}
          />
        </div>
      ) : (
        <span className="text-body-sm text-subtle">{t("hours.closed")}</span>
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
      className="flex items-center gap-md rounded-lg border border-hairline p-md transition-colors hover:border-brand-soft hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
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
  const t = useTranslations("shop");
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
      setErr(e instanceof Error ? e.message : t("errors.upload"));
    } finally {
      setUploading(false);
    }
  }

  const buttons = (
    <>
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
        <ImagePlus size={16} /> {uploading ? t("image.uploading") : url ? t("image.replace") : t("image.upload")}
      </button>
      {url ? (
        <button
          type="button"
          onClick={() => onChange(null)}
          className="inline-flex h-9 items-center gap-sm rounded-button px-md text-label-md text-muted transition-colors hover:text-error"
        >
          <Trash2 size={16} /> {t("image.remove")}
        </button>
      ) : null}
      {err ? <span className="text-body-sm text-error">{err}</span> : null}
    </>
  );

  // Plain block root (not flex) so the banner's width can't collapse via a
  // flex cross-axis / percentage-in-shrink-to-fit quirk.
  return (
    <div>
      <p className="mb-xs text-label-md text-muted">{label}</p>
      {rounded ? (
        // Square logo: fixed-size preview beside its buttons.
        <div className="flex items-center gap-md">
          <div className={`relative shrink-0 overflow-hidden rounded-full border border-hairline bg-surface-tint ${aspect}`}>
            {src ? (
              <Image src={src} alt={label} fill unoptimized className="object-cover" sizes="96px" />
            ) : (
              <span className="flex size-full items-center justify-center text-subtle">
                <ImagePlus size={20} />
              </span>
            )}
          </div>
          <div className="flex flex-col gap-sm">{buttons}</div>
        </div>
      ) : (
        // Wide banner: dimensions via inline styles (immune to JIT/flex issues);
        // background-image covers the fixed box. A full-width block, so it fills.
        <div>
          <div
            role={src ? "img" : undefined}
            aria-label={src ? label : undefined}
            className="flex items-center justify-center rounded-lg border border-hairline bg-surface-tint text-subtle"
            style={{
              width: "100%",
              maxWidth: "36rem",
              height: "10rem",
              backgroundImage: src ? `url("${src}")` : undefined,
              backgroundSize: "cover",
              backgroundPosition: "center",
            }}
          >
            {src ? null : <ImagePlus size={20} />}
          </div>
          <div className="mt-sm flex flex-wrap items-center gap-sm">{buttons}</div>
        </div>
      )}
    </div>
  );
}
 
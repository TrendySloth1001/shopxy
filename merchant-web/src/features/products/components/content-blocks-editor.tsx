"use client";

import { useRef, useState, type ChangeEvent } from "react";
import { useTranslations } from "next-intl";
import { ArrowDown, ArrowUp, Plus, X, Upload } from "@/shared/icons";
import { uploadImage } from "../api";
import { ProductThumb } from "./product-thumb";
import { MiniButton, SelectField } from "./form-controls";
import { StringListEditor } from "./string-list-editor";

export type Block = { kind: string } & Record<string, unknown>;

const KINDS = ["HERO", "FEATURE", "COMPARISON", "GALLERY", "TEXT"] as const;
const cell =
  "h-10 w-full rounded-input border border-hairline bg-field px-md text-body-md text-ink outline-none placeholder:text-subtle focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft";
const area =
  "w-full rounded-input border border-hairline bg-field px-md py-sm text-body-md text-ink outline-none resize-y placeholder:text-subtle focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft";

function emptyBlock(kind: string): Block {
  switch (kind) {
    case "HERO":
      return { kind, imageUrl: "", headline: "", subtext: "" };
    case "FEATURE":
      return { kind, imageUrl: "", side: "LEFT", title: "", body: "" };
    case "COMPARISON":
      return { kind, columns: [{ label: "", values: [""] }], rows: [""] };
    case "GALLERY":
      return { kind, images: [{ url: "", caption: "" }] };
    default:
      return { kind: "TEXT", markdown: "" };
  }
}

/** A+ content blocks editor (max 8). Mirrors the backend discriminated union. */
export function ContentBlocksEditor({
  blocks,
  onChange,
}: {
  blocks: Block[];
  onChange: (next: Block[]) => void;
}) {
  const t = useTranslations("products");
  function patch(i: number, p: Record<string, unknown>) {
    onChange(blocks.map((b, idx) => (idx === i ? { ...b, ...p } : b)));
  }
  function move(i: number, dir: -1 | 1) {
    const t = i + dir;
    if (t < 0 || t >= blocks.length) return;
    const next = [...blocks];
    const [m] = next.splice(i, 1);
    next.splice(t, 0, m);
    onChange(next);
  }

  return (
    <div className="flex flex-col gap-lg">
      {blocks.map((b, i) => (
        <div key={i} className="rounded-md border border-hairline p-md">
          <div className="flex items-center justify-between gap-sm">
            <span className="text-label-md uppercase tracking-wide text-muted">
              {b.kind}
            </span>
            <div className="flex gap-px">
              <button type="button" onClick={() => move(i, -1)} disabled={i === 0}
                aria-label={t("contentBlocks.moveUp")} className="rounded-md p-xs text-muted hover:bg-surface-tint hover:text-ink disabled:text-disabled">
                <ArrowUp size={14} />
              </button>
              <button type="button" onClick={() => move(i, 1)} disabled={i === blocks.length - 1}
                aria-label={t("contentBlocks.moveDown")} className="rounded-md p-xs text-muted hover:bg-surface-tint hover:text-ink disabled:text-disabled">
                <ArrowDown size={14} />
              </button>
              <button type="button" onClick={() => onChange(blocks.filter((_, idx) => idx !== i))}
                aria-label={t("contentBlocks.removeBlock")} className="rounded-md p-xs text-muted hover:bg-surface-tint hover:text-ink">
                <X size={14} />
              </button>
            </div>
          </div>
          <div className="mt-sm">
            <BlockFields block={b} onPatch={(p) => patch(i, p)} />
          </div>
        </div>
      ))}

      {blocks.length < 8 ? (
        <div className="flex flex-wrap gap-sm">
          {KINDS.map((k) => (
            <MiniButton key={k} onClick={() => onChange([...blocks, emptyBlock(k)])}>
              <Plus size={16} /> {k}
            </MiniButton>
          ))}
        </div>
      ) : null}
    </div>
  );
}

function BlockFields({
  block,
  onPatch,
}: {
  block: Block;
  onPatch: (p: Record<string, unknown>) => void;
}) {
  const t = useTranslations("products");
  switch (block.kind) {
    case "HERO":
      return (
        <div className="flex flex-col gap-sm">
          <ImageField label={t("contentBlocks.heroImage")} url={(block.imageUrl as string) ?? ""} onUrl={(u) => onPatch({ imageUrl: u })} />
          <input className={cell} placeholder={t("contentBlocks.headlinePlaceholder")} value={(block.headline as string) ?? ""} onChange={(e) => onPatch({ headline: e.target.value })} />
          <input className={cell} placeholder={t("contentBlocks.subtextPlaceholder")} value={(block.subtext as string) ?? ""} onChange={(e) => onPatch({ subtext: e.target.value })} />
        </div>
      );
    case "FEATURE":
      return (
        <div className="flex flex-col gap-sm">
          <ImageField label={t("contentBlocks.featureImage")} url={(block.imageUrl as string) ?? ""} onUrl={(u) => onPatch({ imageUrl: u })} />
          <SelectField
            label={t("contentBlocks.imageSide")}
            value={(block.side as string) ?? "LEFT"}
            onChange={(v) => onPatch({ side: v })}
            options={[{ value: "LEFT", label: t("contentBlocks.sideLeft") }, { value: "RIGHT", label: t("contentBlocks.sideRight") }]}
          />
          <input className={cell} placeholder={t("contentBlocks.titlePlaceholder")} value={(block.title as string) ?? ""} onChange={(e) => onPatch({ title: e.target.value })} />
          <textarea className={area} rows={3} placeholder={t("contentBlocks.bodyPlaceholder")} value={(block.body as string) ?? ""} onChange={(e) => onPatch({ body: e.target.value })} />
        </div>
      );
    case "TEXT":
      return (
        <textarea className={area} rows={5} placeholder={t("contentBlocks.markdownPlaceholder")} value={(block.markdown as string) ?? ""} onChange={(e) => onPatch({ markdown: e.target.value })} />
      );
    case "GALLERY": {
      const images = (block.images as Array<{ url: string; caption?: string }>) ?? [];
      return (
        <div className="flex flex-col gap-sm">
          {images.map((img, gi) => (
            <div key={gi} className="flex items-center gap-sm">
              <ImageField label="" url={img.url} onUrl={(u) => onPatch({ images: images.map((x, idx) => (idx === gi ? { ...x, url: u } : x)) })} compact />
              <input className={cell} placeholder={t("contentBlocks.captionPlaceholder")} value={img.caption ?? ""} onChange={(e) => onPatch({ images: images.map((x, idx) => (idx === gi ? { ...x, caption: e.target.value } : x)) })} />
              <button type="button" aria-label={t("contentBlocks.remove")} onClick={() => onPatch({ images: images.filter((_, idx) => idx !== gi) })} className="rounded-md p-sm text-muted hover:bg-surface-tint hover:text-ink">
                <X size={16} />
              </button>
            </div>
          ))}
          <MiniButton onClick={() => onPatch({ images: [...images, { url: "", caption: "" }] })}>
            <Plus size={16} /> {t("contentBlocks.addImage")}
          </MiniButton>
        </div>
      );
    }
    case "COMPARISON": {
      const columns = (block.columns as Array<{ label: string; values: string[] }>) ?? [];
      const rows = (block.rows as string[]) ?? [];
      return (
        <div className="flex flex-col gap-md">
          <div>
            <p className="text-label-md text-muted">{t("contentBlocks.rows")}</p>
            <StringListEditor items={rows} onChange={(r) => onPatch({ rows: r })} placeholder={t("contentBlocks.rowLabelPlaceholder")} />
          </div>
          {columns.map((col, ci) => (
            <div key={ci} className="rounded-md border border-hairline p-sm">
              <div className="flex items-center gap-sm">
                <input className={cell} placeholder={t("contentBlocks.columnLabelPlaceholder")} value={col.label} onChange={(e) => onPatch({ columns: columns.map((x, idx) => (idx === ci ? { ...x, label: e.target.value } : x)) })} />
                <button type="button" aria-label={t("contentBlocks.removeColumn")} onClick={() => onPatch({ columns: columns.filter((_, idx) => idx !== ci) })} className="rounded-md p-sm text-muted hover:bg-surface-tint hover:text-ink">
                  <X size={16} />
                </button>
              </div>
              <div className="mt-sm">
                <StringListEditor items={col.values} onChange={(v) => onPatch({ columns: columns.map((x, idx) => (idx === ci ? { ...x, values: v } : x)) })} placeholder={t("contentBlocks.valuePlaceholder")} />
              </div>
            </div>
          ))}
          <MiniButton onClick={() => onPatch({ columns: [...columns, { label: "", values: [""] }] })}>
            <Plus size={16} /> {t("contentBlocks.addColumn")}
          </MiniButton>
        </div>
      );
    }
    default:
      return null;
  }
}

function ImageField({
  label,
  url,
  onUrl,
  compact,
}: {
  label: string;
  url: string;
  onUrl: (url: string) => void;
  compact?: boolean;
}) {
  const t = useTranslations("products");
  const ref = useRef<HTMLInputElement>(null);
  const [busy, setBusy] = useState(false);
  async function onFile(e: ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    e.target.value = "";
    if (!file) return;
    setBusy(true);
    try {
      onUrl(await uploadImage(file));
    } catch {
      /* ignore; user can retry */
    } finally {
      setBusy(false);
    }
  }
  return (
    <div className="flex items-center gap-sm">
      {label ? <span className="sr-only">{label}</span> : null}
      <ProductThumb url={url || null} alt={label || t("contentBlocks.imageAlt")} size={compact ? 40 : 56} />
      <button type="button" onClick={() => ref.current?.click()} disabled={busy}
        className="inline-flex h-9 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint disabled:text-disabled">
        <Upload size={16} /> {busy ? t("contentBlocks.uploading") : url ? t("contentBlocks.replace") : t("contentBlocks.upload")}
      </button>
      <input ref={ref} type="file" accept="image/png,image/jpeg,image/webp" className="hidden" onChange={onFile} />
    </div>
  );
}

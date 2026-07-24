"use client";

import { useRef, useState, type ChangeEvent } from "react";
import { useTranslations } from "next-intl";
import { ImagePlus, X, ArrowUp, ArrowDown } from "@/shared/icons";
import {
  addImage,
  deleteImage,
  reorderImages,
  uploadImage,
} from "../api";
import { ProductThumb } from "./product-thumb";

type Item = { id?: string; url: string };

/**
 * Product image manager.
 * - Edit mode (`productId` set): add / remove / reorder hit the live endpoints.
 * - Create mode (no `productId`): collect URLs locally; the parent submits them
 *   as `imageUrls` in the create payload.
 */
export function ImageManager({
  productId,
  initial,
  onChange,
}: {
  productId?: string;
  initial: Item[];
  onChange?: (urls: string[]) => void;
}) {
  const t = useTranslations("products");
  const [items, setItems] = useState<Item[]>(initial);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  function commit(next: Item[]) {
    setItems(next);
    onChange?.(next.map((i) => i.url));
  }

  async function onFiles(event: ChangeEvent<HTMLInputElement>) {
    const files = Array.from(event.target.files ?? []);
    event.target.value = "";
    if (files.length === 0) return;
    setError(null);
    setBusy(true);
    try {
      const next = [...items];
      for (const file of files) {
        const url = await uploadImage(file);
        if (productId) {
          const img = await addImage(productId, url);
          next.push({ id: img.id, url: img.url });
        } else {
          next.push({ url });
        }
      }
      commit(next);
    } catch (e) {
      setError(e instanceof Error ? e.message : t("imageManager.uploadError"));
    } finally {
      setBusy(false);
    }
  }

  async function remove(index: number) {
    const item = items[index];
    if (!item) return;
    setBusy(true);
    setError(null);
    try {
      if (productId && item.id) await deleteImage(productId, item.id);
      commit(items.filter((_, i) => i !== index));
    } catch (e) {
      setError(e instanceof Error ? e.message : t("imageManager.removeError"));
    } finally {
      setBusy(false);
    }
  }

  async function move(index: number, dir: -1 | 1) {
    const target = index + dir;
    if (target < 0 || target >= items.length) return;
    const next = [...items];
    const [moved] = next.splice(index, 1);
    next.splice(target, 0, moved);
    setBusy(true);
    setError(null);
    try {
      if (productId && next.every((i) => i.id)) {
        await reorderImages(productId, next.map((i) => i.id as string));
      }
      commit(next);
    } catch (e) {
      setError(e instanceof Error ? e.message : t("imageManager.reorderError"));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="flex flex-col gap-md">
      {error ? <p className="text-body-sm text-error">{error}</p> : null}
      <div className="flex flex-wrap gap-md">
        {items.map((item, i) => (
          <div key={item.id ?? `${item.url}-${i}`} className="flex flex-col items-center gap-xs">
            <div className="relative">
              <ProductThumb url={item.url} alt={t("imageManager.imageAlt", { index: i + 1 })} size={88} />
              <button
                type="button"
                onClick={() => remove(i)}
                disabled={busy}
                aria-label={t("imageManager.removeImage")}
                className="absolute -right-2 -top-2 flex size-6 items-center justify-center rounded-full bg-inverse-surface text-on-inverse transition-opacity hover:opacity-90 disabled:opacity-50"
              >
                <X size={14} />
              </button>
            </div>
            <div className="flex gap-px">
              <button
                type="button"
                onClick={() => move(i, -1)}
                disabled={busy || i === 0}
                aria-label={t("imageManager.moveLeft")}
                className="rounded-md p-xs text-muted hover:bg-surface-tint hover:text-ink disabled:text-disabled"
              >
                <ArrowUp size={14} className="-rotate-90" />
              </button>
              <button
                type="button"
                onClick={() => move(i, 1)}
                disabled={busy || i === items.length - 1}
                aria-label={t("imageManager.moveRight")}
                className="rounded-md p-xs text-muted hover:bg-surface-tint hover:text-ink disabled:text-disabled"
              >
                <ArrowDown size={14} className="-rotate-90" />
              </button>
            </div>
          </div>
        ))}

        <button
          type="button"
          onClick={() => inputRef.current?.click()}
          disabled={busy}
          className="flex size-[88px] flex-col items-center justify-center gap-xs rounded-md border border-dashed border-hairline text-subtle transition-colors hover:border-brand hover:text-brand focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:text-disabled"
        >
          <ImagePlus size={20} />
          <span className="text-body-sm">{busy ? "…" : t("imageManager.add")}</span>
        </button>
      </div>
      <input
        ref={inputRef}
        type="file"
        accept="image/png,image/jpeg,image/webp"
        multiple
        className="hidden"
        onChange={onFiles}
      />
    </div>
  );
}

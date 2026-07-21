"use client";

import { useRef, useState } from "react";
import Image from "next/image";
import { useTranslations } from "next-intl";
import { ImagePlus, Trash2, Upload } from "@/shared/icons";
import { mediaSrc } from "@/features/products/components/product-thumb";
import { uploadImage } from "@/features/products/api";

/**
 * Reusable image-upload control: a preview tile (square or banner) plus an
 * upload / replace / remove action. Forwards the file to `/api/upload` and
 * stores the returned relative URL. Used by the marketing editors (slide
 * background + brand logo, spotlight hero).
 */
export function ImageUploadField({
  label,
  helper,
  url,
  onChange,
  aspect = "banner",
}: {
  label: string;
  helper?: string;
  url: string | null;
  onChange: (url: string | null) => void;
  /** "banner" → wide 3:1 tile; "square" → 96px; "round" → 96px circle. */
  aspect?: "banner" | "square" | "round";
}) {
  const t = useTranslations("common");
  const inputRef = useRef<HTMLInputElement>(null);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const src = mediaSrc(url);

  async function pick(file: File) {
    setUploading(true);
    setError(null);
    try {
      onChange(await uploadImage(file));
    } catch (e) {
      setError(e instanceof Error ? e.message : t("imageUpload.failed"));
    } finally {
      setUploading(false);
    }
  }

  const tileShape =
    aspect === "banner"
      ? "aspect-[3/1] w-full max-w-md rounded-lg"
      : aspect === "round"
        ? "size-24 rounded-full"
        : "size-24 rounded-lg";

  return (
    <div className="flex flex-col gap-xs">
      <span className="text-label-md text-muted">{label}</span>
      <div className="flex items-center gap-md">
        <div className={`relative shrink-0 overflow-hidden border border-hairline bg-surface-tint ${tileShape}`}>
          {src ? (
            <Image src={src} alt={label} fill unoptimized className="object-cover" sizes="384px" />
          ) : (
            <span className="flex size-full items-center justify-center text-subtle">
              <ImagePlus size={20} />
            </span>
          )}
        </div>
        <div className="flex flex-col items-start gap-sm">
          <input
            ref={inputRef}
            type="file"
            accept="image/*"
            hidden
            onChange={(e) => {
              const f = e.target.files?.[0];
              if (f) void pick(f);
              e.target.value = "";
            }}
          />
          <button
            type="button"
            onClick={() => inputRef.current?.click()}
            disabled={uploading}
            className="inline-flex h-9 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint disabled:text-disabled"
          >
            <Upload size={16} /> {uploading ? t("imageUpload.uploading") : url ? t("imageUpload.replace") : t("imageUpload.upload")}
          </button>
          {url ? (
            <button
              type="button"
              onClick={() => onChange(null)}
              className="inline-flex h-9 items-center gap-sm rounded-button px-md text-label-md text-muted transition-colors hover:text-error"
            >
              <Trash2 size={16} /> {t("imageUpload.remove")}
            </button>
          ) : null}
          {helper ? <span className="text-body-sm text-subtle">{helper}</span> : null}
          {error ? <span className="text-body-sm text-error">{error}</span> : null}
        </div>
      </div>
    </div>
  );
}

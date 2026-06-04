import Image from "next/image";
import { mediaSrc } from "./product-thumb";

/**
 * Read-only renderer for A+ content blocks — mirrors the customer PDP. Blocks
 * are loosely typed (backend passthrough), so per-kind fields are read defensively.
 */
type Block = Record<string, unknown>;

function str(v: unknown): string | undefined {
  return typeof v === "string" && v.length > 0 ? v : undefined;
}

function ContentImage({ url, alt }: { url?: string; alt: string }) {
  const src = mediaSrc(url ?? null);
  if (!src) return null;
  return (
    <Image
      src={src}
      alt={alt}
      width={1200}
      height={675}
      unoptimized
      className="h-auto w-full rounded-lg border border-hairline object-cover"
    />
  );
}

export function ContentBlocksView({ blocks }: { blocks: Block[] }) {
  return (
    <div className="flex flex-col gap-xxl">
      {blocks.map((b, i) => (
        <BlockView key={i} block={b} />
      ))}
    </div>
  );
}

function BlockView({ block }: { block: Block }) {
  const kind = String(block.kind);

  if (kind === "HERO") {
    return (
      <figure>
        <ContentImage url={str(block.imageUrl)} alt={str(block.headline) ?? "Hero"} />
        <figcaption className="mt-md">
          <p className="text-headline-sm text-ink">{str(block.headline)}</p>
          {str(block.subtext) ? (
            <p className="mt-xs text-body-md text-muted">{str(block.subtext)}</p>
          ) : null}
        </figcaption>
      </figure>
    );
  }

  if (kind === "FEATURE") {
    const right = str(block.side) === "RIGHT";
    return (
      <div className="grid items-center gap-lg md:grid-cols-2">
        <div className={right ? "md:order-2" : ""}>
          <ContentImage url={str(block.imageUrl)} alt={str(block.title) ?? "Feature"} />
        </div>
        <div className={right ? "md:order-1" : ""}>
          <p className="text-title-lg text-ink">{str(block.title)}</p>
          {str(block.body) ? (
            <p className="mt-sm whitespace-pre-line text-body-md text-muted">
              {str(block.body)}
            </p>
          ) : null}
        </div>
      </div>
    );
  }

  if (kind === "TEXT") {
    const md = str(block.markdown) ?? "";
    // Lightweight render: preserve paragraph + line breaks (backend sanitises
    // the markdown; full markdown rendering is a future enhancement).
    return (
      <div className="flex max-w-content flex-col gap-md">
        {md.split(/\n{2,}/).map((para, i) => (
          <p key={i} className="whitespace-pre-line text-body-md text-ink">
            {para}
          </p>
        ))}
      </div>
    );
  }

  if (kind === "GALLERY") {
    const images = (block.images as Array<{ url?: string; caption?: string }>) ?? [];
    return (
      <div className="grid gap-md sm:grid-cols-2 lg:grid-cols-3">
        {images.map((img, i) => (
          <figure key={i}>
            <ContentImage url={str(img.url)} alt={str(img.caption) ?? `Image ${i + 1}`} />
            {str(img.caption) ? (
              <figcaption className="mt-xs text-body-sm text-muted">
                {str(img.caption)}
              </figcaption>
            ) : null}
          </figure>
        ))}
      </div>
    );
  }

  if (kind === "COMPARISON") {
    const columns = (block.columns as Array<{ label?: string; values?: string[] }>) ?? [];
    const rows = (block.rows as string[]) ?? [];
    return (
      <div className="overflow-x-auto">
        <table className="w-full border-collapse text-body-sm">
          <thead>
            <tr>
              <th className="border-b border-hairline py-sm pr-md text-left text-label-md text-subtle" />
              {columns.map((c, ci) => (
                <th
                  key={ci}
                  className="border-b border-hairline px-md py-sm text-left text-label-md text-ink"
                >
                  {c.label}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {rows.map((row, ri) => (
              <tr key={ri}>
                <td className="border-b border-hairline py-sm pr-md text-muted">{row}</td>
                {columns.map((c, ci) => (
                  <td key={ci} className="border-b border-hairline px-md py-sm text-ink">
                    {c.values?.[ri] ?? "—"}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    );
  }

  return null;
}

import Image from "next/image";
import ReactMarkdown, { type Components } from "react-markdown";
import { mediaSrc } from "./product-thumb";

const mdComponents: Components = {
  p: ({ children }) => <p className="mb-md text-body-md text-ink">{children}</p>,
  strong: ({ children }) => <strong className="font-semibold">{children}</strong>,
  em: ({ children }) => <em className="italic">{children}</em>,
  ul: ({ children }) => (
    <ul className="mb-md list-disc space-y-xs pl-lg text-body-md text-ink">{children}</ul>
  ),
  ol: ({ children }) => (
    <ol className="mb-md list-decimal space-y-xs pl-lg text-body-md text-ink">{children}</ol>
  ),
  li: ({ children }) => <li>{children}</li>,
  h1: ({ children }) => <h3 className="mb-sm mt-lg text-title-lg text-ink">{children}</h3>,
  h2: ({ children }) => <h3 className="mb-sm mt-lg text-title-md text-ink">{children}</h3>,
  h3: ({ children }) => <h4 className="mb-xs mt-md text-title-sm text-ink">{children}</h4>,
  a: ({ children, href }) => (
    <a
      href={href}
      target="_blank"
      rel="noopener noreferrer"
      className="text-brand-strong underline underline-offset-2"
    >
      {children}
    </a>
  ),
  code: ({ children }) => (
    <code className="rounded-xs bg-surface-tint px-xs py-px text-body-sm">{children}</code>
  ),
  blockquote: ({ children }) => (
    <blockquote className="mb-md border-l border-hairline pl-md text-body-md text-muted">
      {children}
    </blockquote>
  ),
};

type Block = Record<string, unknown>;

function str(v: unknown): string | undefined {
  return typeof v === "string" && v.length > 0 ? v : undefined;
}

function ContentImage({
  url,
  alt,
  aspect = "aspect-video",
}: {
  url?: string;
  alt: string;
  aspect?: string;
}) {
  const src = mediaSrc(url ?? null);
  if (!src) return null;
  return (
    <div className={`relative w-full overflow-hidden rounded-lg border border-hairline bg-surface-tint ${aspect}`}>
      <Image
        src={src}
        alt={alt}
        fill
        unoptimized
        sizes="(max-width: 768px) 100vw, 768px"
        className="object-cover"
      />
    </div>
  );
}

export function ContentBlocksView({ blocks }: { blocks: Block[] }) {
  return (
    <div className="flex max-w-3xl flex-col gap-xl">
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
        {str(block.headline) || str(block.subtext) ? (
          <figcaption className="mt-md">
            <p className="text-title-lg text-ink">{str(block.headline)}</p>
            {str(block.subtext) ? (
              <p className="mt-xs text-body-md text-muted">{str(block.subtext)}</p>
            ) : null}
          </figcaption>
        ) : null}
      </figure>
    );
  }

  if (kind === "FEATURE") {
    const right = str(block.side) === "RIGHT";
    return (
      <div className="grid items-center gap-lg sm:grid-cols-2">
        <div className={right ? "sm:order-2" : ""}>
          <ContentImage
            url={str(block.imageUrl)}
            alt={str(block.title) ?? "Feature"}
            aspect="aspect-[4/3]"
          />
        </div>
        <div className={right ? "sm:order-1" : ""}>
          <p className="text-title-md text-ink">{str(block.title)}</p>
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
    return (
      <div>
        <ReactMarkdown components={mdComponents}>{md}</ReactMarkdown>
      </div>
    );
  }

  if (kind === "GALLERY") {
    const images = (block.images as Array<{ url?: string; caption?: string }>) ?? [];
    return (
      <div className="grid grid-cols-2 gap-md sm:grid-cols-3">
        {images.map((img, i) => (
          <figure key={i}>
            <ContentImage
              url={str(img.url)}
              alt={str(img.caption) ?? `Image ${i + 1}`}
              aspect="aspect-square"
            />
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

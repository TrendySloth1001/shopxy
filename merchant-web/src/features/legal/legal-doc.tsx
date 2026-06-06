import Link from "next/link";
import { ArrowLeft } from "lucide-react";

/**
 * Shared reading layout for the public legal pages (/legal/*). Centered reading
 * rail, hairline-separated sections, token-only. Content is supplied per page.
 */
export function LegalDoc({
  title,
  updated,
  children,
}: {
  title: string;
  updated: string;
  children: React.ReactNode;
}) {
  return (
    <main className="mx-auto max-w-content px-lg py-xxxl">
      <Link
        href="/login"
        className="inline-flex items-center gap-xs text-label-md text-muted transition-colors hover:text-ink"
      >
        <ArrowLeft size={16} /> ShopXY
      </Link>
      <h1 className="mt-md text-headline-md text-ink">{title}</h1>
      <p className="mt-xs text-body-sm text-subtle">Last updated {updated}</p>
      <div className="mt-xl flex flex-col gap-xl">{children}</div>
    </main>
  );
}

export function LegalSection({ heading, children }: { heading: string; children: React.ReactNode }) {
  return (
    <section className="border-t border-hairline pt-lg">
      <h2 className="text-title-sm text-ink">{heading}</h2>
      <div className="mt-sm flex flex-col gap-sm text-body-md text-muted">{children}</div>
    </section>
  );
}

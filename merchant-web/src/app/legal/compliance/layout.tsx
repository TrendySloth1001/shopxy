import Link from "next/link";
import { ArrowLeft } from "lucide-react";
import { ComplianceNav } from "@/features/legal/compliance-nav";

/**
 * Documentation shell for /legal/compliance: a shared header, a sticky topic
 * sidebar on the left (large screens) and the per-topic content on the right.
 * Each topic is its own route, so the content stays readable instead of one
 * endless page.
 */
export default function ComplianceLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <main className="mx-auto max-w-docs px-lg py-xxxl">
      <Link
        href="/login"
        className="inline-flex items-center gap-xs text-label-md text-muted transition-colors hover:text-ink"
      >
        <ArrowLeft size={16} /> ShopXY
      </Link>
      <h1 className="mt-md font-display text-headline-md text-ink">
        Compliance, laws &amp; formulas
      </h1>
      <p className="mt-xs text-body-sm text-subtle">Last updated June 2026</p>

      <div className="mt-xl flex flex-col gap-lg lg:grid lg:grid-cols-4 lg:gap-xxl">
        <aside className="lg:col-span-1 lg:self-start lg:sticky lg:top-xxl">
          <ComplianceNav />
        </aside>
        <div className="min-w-0 lg:col-span-3">{children}</div>
      </div>
    </main>
  );
}

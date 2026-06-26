import type { Metadata } from "next";
import Link from "next/link";
import { ArrowRight } from "lucide-react";
import { GrievanceOfficerSection } from "@/features/legal/grievance-officer";
import { INTRO, SECTIONS } from "@/features/legal/compliance-content";

export const metadata: Metadata = {
  title: "Compliance, laws & formulas · ShopXY",
};

export default function ComplianceOverviewPage() {
  return (
    <div className="flex flex-col gap-xl">
      <p className="text-body-md text-muted">{INTRO}</p>

      <div className="flex flex-col gap-sm">
        <h2 className="text-label-lg uppercase tracking-wide text-subtle">Topics</h2>
        <ul className="flex flex-col divide-y divide-hairline">
          {SECTIONS.map((s) => (
            <li key={s.id}>
              <Link
                href={`/legal/compliance/${s.id}`}
                className="group flex items-start justify-between gap-md py-md transition-colors hover:bg-surface-tint"
              >
                <span className="flex flex-col gap-xs">
                  <span className="font-display text-title-sm text-ink">{s.heading}</span>
                  <span className="text-body-sm text-muted">{s.summary}</span>
                </span>
                <ArrowRight
                  size={18}
                  className="mt-xs shrink-0 text-subtle transition-colors group-hover:text-ink"
                />
              </Link>
            </li>
          ))}
        </ul>
      </div>

      <div className="border-t border-hairline pt-lg">
        <GrievanceOfficerSection />
      </div>

      <div className="border-t border-hairline pt-lg">
        <h2 className="text-title-sm text-ink">A note on scope</h2>
        <p className="mt-sm text-body-md text-muted">
          These pages describe how ShopXY is built today and are provided for general
          information; they are not legal advice. Where a value is still being
          finalised (for example, the named Grievance Officer or the hosting
          provider), it is marked as pending on the relevant policy page. The{" "}
          <Link href="/legal/terms" className="text-ink underline hover:text-brand">
            Terms of Service
          </Link>{" "}
          and{" "}
          <Link href="/legal/privacy" className="text-ink underline hover:text-brand">
            Privacy Policy
          </Link>{" "}
          remain the operative documents.
        </p>
      </div>
    </div>
  );
}

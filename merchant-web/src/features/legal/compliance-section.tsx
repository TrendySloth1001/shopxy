import type { Section } from "./compliance-content";

/**
 * Renders one compliance topic. Grouped with hairline dividers and whitespace
 * — no boxes, no coloured rules (CLAUDE.md §9b). Reads top-down: a one-line
 * summary and prose, then the key points, then how it is calculated, then the
 * governing statutes as de-emphasised reference material.
 */
export function ComplianceSectionBody({ section }: { section: Section }) {
  return (
    <div className="flex flex-col gap-xxl">
      {/* Lead + prose. */}
      <div className="flex flex-col gap-md">
        <p className="text-body-lg text-ink">{section.summary}</p>
        <div className="flex flex-col gap-md text-body-md text-muted">
          {section.body.map((p, i) => (
            <p key={i}>{p}</p>
          ))}
        </div>
      </div>

      {/* Key points. */}
      <section className="border-t border-hairline pt-xl">
        <h3 className="text-label-md uppercase tracking-wide text-subtle">
          Key points
        </h3>
        <ul className="mt-md flex list-disc flex-col gap-sm pl-lg text-body-md text-ink marker:text-subtle">
          {section.keyPoints.map((kp, i) => (
            <li key={i}>{kp}</li>
          ))}
        </ul>
      </section>

      {/* Formulas. */}
      {section.formulas.length > 0 ? (
        <section className="border-t border-hairline pt-xl">
          <h3 className="text-label-md uppercase tracking-wide text-subtle">
            How it&apos;s calculated
          </h3>
          <ul className="mt-md flex flex-col divide-y divide-hairline">
            {section.formulas.map((f) => (
              <li key={f.label} className="py-md first:pt-0 last:pb-0">
                <p className="text-label-lg text-ink">{f.label}</p>
                <code className="mt-xs block whitespace-pre-wrap break-words font-mono text-body-sm text-ink">
                  {f.expression}
                </code>
                <p className="mt-xs text-body-sm text-subtle">{f.note}</p>
              </li>
            ))}
          </ul>
        </section>
      ) : null}

      {/* Governing law — reference material, de-emphasised. */}
      <section className="border-t border-hairline pt-xl">
        <h3 className="text-label-md uppercase tracking-wide text-subtle">
          Governing law
        </h3>
        <p className="mt-sm text-body-sm text-muted">
          {section.lawRefs.join("  ·  ")}
        </p>
      </section>
    </div>
  );
}

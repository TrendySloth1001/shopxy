import { getTranslations } from "next-intl/server";
import type { Section } from "./compliance-content";

export async function ComplianceSectionBody({ section }: { section: Section }) {
  const t = await getTranslations("legal");
  const base = `compliance.${section.key}`;

  const body = Array.from({ length: section.bodyCount }, (_, i) => t(`${base}.body.${i}`));
  const keyPoints = Array.from({ length: section.keyPointCount }, (_, i) =>
    t(`${base}.keyPoints.${i}`),
  );
  const lawRefs = Array.from({ length: section.lawRefCount }, (_, i) => t(`${base}.lawRefs.${i}`));

  return (
    <div className="flex flex-col gap-xxl">
      <div className="flex flex-col gap-md">
        <p className="text-body-lg text-ink">{t(`${base}.summary`)}</p>
        <div className="flex flex-col gap-md text-body-md text-muted">
          {body.map((p, i) => (
            <p key={i}>{p}</p>
          ))}
        </div>
      </div>

      <section className="border-t border-hairline pt-xl">
        <h3 className="text-label-md uppercase tracking-wide text-subtle">
          {t("compliance.section.keyPoints")}
        </h3>
        <ul className="mt-md flex list-disc flex-col gap-sm pl-lg text-body-md text-ink marker:text-subtle">
          {keyPoints.map((kp, i) => (
            <li key={i}>{kp}</li>
          ))}
        </ul>
      </section>

      {section.formulas.length > 0 ? (
        <section className="border-t border-hairline pt-xl">
          <h3 className="text-label-md uppercase tracking-wide text-subtle">
            {t("compliance.section.howCalculated")}
          </h3>
          <ul className="mt-md flex flex-col divide-y divide-hairline">
            {section.formulas.map((f) => (
              <li key={f.labelKey} className="py-md first:pt-0 last:pb-0">
                <p className="text-label-lg text-ink">{t(f.labelKey)}</p>
                <code className="mt-xs block whitespace-pre-wrap break-words font-mono text-body-sm text-ink">
                  {t(f.expressionKey)}
                </code>
                <p className="mt-xs text-body-sm text-subtle">{t(f.noteKey)}</p>
              </li>
            ))}
          </ul>
        </section>
      ) : null}

      <section className="border-t border-hairline pt-xl">
        <h3 className="text-label-md uppercase tracking-wide text-subtle">
          {t("compliance.section.governingLaw")}
        </h3>
        <p className="mt-sm text-body-sm text-muted">{lawRefs.join("  ·  ")}</p>
      </section>
    </div>
  );
}

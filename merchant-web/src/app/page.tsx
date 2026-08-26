import { getTranslations } from "next-intl/server";
import { Divider } from "@/shared/ui/divider";
import { color, radius, shadow, space, tokens } from "@/shared/ui/tokens";

function Section({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section className="py-xxl">
      <h2 className="text-label-lg uppercase tracking-wide text-subtle">
        {title}
      </h2>
      <div className="mt-lg">{children}</div>
    </section>
  );
}

function Swatch({ name, value }: { name: string; value: string }) {
  return (
    <div className="flex items-center gap-md">
      <span
        className="size-10 shrink-0 rounded-md border border-hairline"
        style={{ backgroundColor: value }}
      />
      <span className="flex flex-col">
        <span className="text-body-md text-ink">{name}</span>
        <span className="text-body-sm text-subtle tabular-nums">{value}</span>
      </span>
    </div>
  );
}

function swatchesFrom(group: Record<string, string>) {
  return Object.entries(group).map(([name, value]) => (
    <Swatch key={name} name={name} value={value} />
  ));
}

export default async function TokensPage() {
  const t = await getTranslations("auth");
  return (
    <main className="mx-auto max-w-content px-lg pb-massive">
      <header className="py-xxxl">
        <p className="text-label-md uppercase tracking-wide text-brand">
          ShopXY · Merchant
        </p>
        <h1 className="mt-xs text-display-sm text-ink">{t("tokens.title")}</h1>
        <p className="mt-sm max-w-form text-body-lg text-muted">
          {t("tokens.intro")}
        </p>
      </header>

      <Divider />

      <Section title={t("tokens.inks")}>
        <div className="grid grid-cols-2 gap-lg sm:grid-cols-3">
          {swatchesFrom(color.ink)}
        </div>
      </Section>
      <Divider />

      <Section title={t("tokens.surfaces")}>
        <div className="grid grid-cols-2 gap-lg sm:grid-cols-3">
          {swatchesFrom(color.surface)}
        </div>
      </Section>
      <Divider />

      <Section title={t("tokens.brandStatus")}>
        <div className="grid grid-cols-2 gap-lg sm:grid-cols-3">
          {swatchesFrom(color.brand)}
          {swatchesFrom(color.status)}
        </div>
      </Section>
      <Divider />

      <Section title={t("tokens.accents")}>
        <div className="grid grid-cols-2 gap-lg sm:grid-cols-3">
          {swatchesFrom(color.accent)}
          {swatchesFrom(color.merchant)}
        </div>
      </Section>
      <Divider />

      <Section title={t("tokens.typeScale")}>
        <div className="flex flex-col gap-md">
          <p className="text-display-sm">{t("tokens.sampleDisplay")}</p>
          <p className="text-headline-md">{t("tokens.sampleHeadline")}</p>
          <p className="text-title-lg">{t("tokens.sampleTitle")}</p>
          <p className="text-body-lg">
            {t("tokens.sampleBody")}
          </p>
          <p className="text-label-md uppercase tracking-wide text-muted">
            {t("tokens.sampleLabel")}
          </p>
        </div>
      </Section>
      <Divider />

      <Section title={t("tokens.spacing")}>
        <div className="flex flex-col gap-sm">
          {Object.entries(space).map(([name, px]) => (
            <div key={name} className="flex items-center gap-md">
              <span className="w-16 text-body-sm text-subtle">
                {name} · {px}
              </span>
              <span className="h-3 bg-brand-soft" style={{ width: px }} />
            </div>
          ))}
        </div>
      </Section>
      <Divider />

      <Section title={t("tokens.radii")}>
        <div className="flex flex-wrap gap-lg">
          {Object.entries(radius).map(([name, px]) => (
            <div key={name} className="flex flex-col items-center gap-sm">
              <span
                className="size-16 border border-hairline bg-surface"
                style={{ borderRadius: px }}
              />
              <span className="text-body-sm text-subtle">{name}</span>
            </div>
          ))}
        </div>
      </Section>
      <Divider />

      <Section title={t("tokens.elevation")}>
        <div className="flex flex-wrap gap-xl">
          {Object.entries(shadow).map(([name, value]) => (
            <div key={name} className="flex flex-col items-center gap-sm">
              <span
                className="size-20 rounded-lg bg-surface"
                style={{ boxShadow: value }}
              />
              <span className="text-body-sm text-subtle">{name}</span>
            </div>
          ))}
        </div>
      </Section>
      <Divider />

      <Section title={t("tokens.motion")}>
        <div className="flex flex-wrap gap-xl text-body-sm text-muted">
          {Object.entries(tokens.duration).map(([name, ms]) => (
            <span key={name}>
              {name} · {ms}ms
            </span>
          ))}
        </div>
      </Section>
    </main>
  );
}

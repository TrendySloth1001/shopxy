import { Divider } from "@/shared/ui/divider";
import { NAV_LABELS } from "@/features/dashboard/nav-items";

export default async function SectionPlaceholderPage({
  params,
}: {
  params: Promise<{ section: string[] }>;
}) {
  const { section } = await params;
  const key = section[0] ?? "";
  const label = NAV_LABELS[key] ?? "Coming soon";

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <h1 className="text-headline-md text-ink">{label}</h1>
      <Divider className="my-xxl" />
      <p className="text-body-md text-muted">
        This section isn’t built yet — the {label} screen is coming soon.
      </p>
    </div>
  );
}

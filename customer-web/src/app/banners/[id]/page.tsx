import type { Metadata } from "next";
import { AppHeader } from "@/features/auth/components/app-header";
import { BannerDetailView } from "@/features/deals/components/banner-detail-view";

type Props = { params: Promise<{ id: string }> };

/**
 * Banner detail page (`/banners/[id]`). Public.
 *
 * Renders the merchant-curated slide: hero image, discount strip, and product
 * grid. Port of the Flutter `BannerSlideDetailPage`.
 */
export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { id } = await params;
  return {
    title: `Banner #${id} — ShopXY`,
    description: "Curated products at exclusive prices.",
  };
}

export default async function BannerDetailPage({ params }: Props) {
  const { id } = await params;
  const bannerId = Number(id);

  return (
    <>
      <AppHeader />
      <main className="mx-auto max-w-shell">
        {Number.isNaN(bannerId) || bannerId <= 0 ? (
          <p className="px-lg py-xl text-body-md text-muted">Invalid banner ID.</p>
        ) : (
          <BannerDetailView bannerId={bannerId} />
        )}
      </main>
    </>
  );
}

import { BannerDetailView } from "@/features/banner/components/banner-detail-view";

/** Banner detail — `/banner/[id]`. Public. Shows the banner + its products. */
export default async function BannerPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return <BannerDetailView id={id} />;
}

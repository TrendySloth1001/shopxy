import { BannerDetailView } from "@/features/banner/components/banner-detail-view";

export default async function BannerPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return <BannerDetailView id={id} />;
}

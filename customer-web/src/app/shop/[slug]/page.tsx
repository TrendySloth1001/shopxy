import type { Metadata } from "next";
import { ShopProfileView } from "@/features/catalog/components/shop-profile-view";

type Props = { params: Promise<{ slug: string }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params;
  const name = slug
    .split("-")
    .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
    .join(" ");
  return {
    title: `${name} — ShopXY`,
    description: `Browse all products from ${name} on ShopXY.`,
  };
}

export default async function ShopPage({ params }: Props) {
  const { slug } = await params;
  return <ShopProfileView slug={slug} />;
}

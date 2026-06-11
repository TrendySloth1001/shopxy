import type { Metadata } from "next";
import { ShopProfileView } from "@/features/catalog/components/shop-profile-view";

type Props = { params: Promise<{ slug: string }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params;
  // Slug is kebab-case e.g. "acme-electronics" → "Acme Electronics"
  const name = slug
    .split("-")
    .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
    .join(" ");
  return {
    title: `${name} — ShopXY`,
    description: `Browse all products from ${name} on ShopXY.`,
  };
}

/** Shop profile page — `/shop/[slug]`. Public. */
export default async function ShopPage({ params }: Props) {
  const { slug } = await params;
  return <ShopProfileView slug={slug} />;
}

import type { Metadata } from "next";
import { CategoryProductsView } from "@/features/catalog/components/category-products-view";

type Props = { params: Promise<{ slug: string }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params;
  const name = slug
    .split("-")
    .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
    .join(" ");
  return {
    title: `${name} — ShopXY`,
    description: `Shop ${name} products on ShopXY.`,
  };
}

export default async function CategoryPage({ params }: Props) {
  const { slug } = await params;
  return <CategoryProductsView slug={slug} />;
}

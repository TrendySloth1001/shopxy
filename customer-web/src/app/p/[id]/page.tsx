import type { Metadata } from "next";
import { backendFetch } from "@/server/auth/session";
import { productDetailSchema, type ProductDetail } from "@/features/pdp/types";
import { PdpClient } from "@/features/pdp/components/pdp-client";
import { resolveImageUrl } from "@/features/home/format";

type PageProps = {
  params: Promise<{ id: string }>;
};

/** Server-side product fetch for SSR + generateMetadata. Returns null on any error. */
async function fetchProductServer(id: string): Promise<ProductDetail | null> {
  try {
    const res = await backendFetch(`/marketplace/products/${encodeURIComponent(id)}`);
    if (!res.ok) return null;
    const raw = await res.json();
    return productDetailSchema.parse(raw);
  } catch {
    return null;
  }
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { id } = await params;
  const product = await fetchProductServer(id);
  if (!product) {
    return {
      title: "Product — ShopXY",
      description: "Shop everything on ShopXY.",
    };
  }
  const imageUrl = product.images[0]?.url
    ? resolveImageUrl(product.images[0].url)
    : undefined;
  const description = product.description
    ? product.description.slice(0, 160)
    : `Buy ${product.name} from ${product.shop?.name ?? "ShopXY"}.`;

  return {
    title: `${product.name} — ShopXY`,
    description,
    openGraph: {
      title: product.name,
      description,
      ...(imageUrl ? { images: [{ url: imageUrl }] } : {}),
    },
  };
}

/**
 * Product Detail Page — server-rendered shell with client interactivity.
 *
 * The Server Component fetches the initial product data for SEO / LCP and
 * passes it as `initialData` to the `PdpClient` hydration boundary. If the
 * server fetch fails (404, 500, timeout) the client component falls through to
 * its own loading + error states.
 */
export default async function ProductDetailPage({ params }: PageProps) {
  const { id } = await params;
  const product = await fetchProductServer(id);

  return (
    <main className="mx-auto max-w-shell">
      <PdpClient productId={Number(id)} initialData={product ?? undefined} />
    </main>
  );
}

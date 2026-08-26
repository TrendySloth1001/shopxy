import type { Metadata } from "next";
import { AppHeader } from "@/features/auth/components/app-header";
import { CategoriesGrid } from "@/features/catalog/components/categories-grid";

export const metadata: Metadata = {
  title: "All Categories — ShopXY",
  description: "Browse all product categories on ShopXY.",
};

export default function CategoriesPage() {
  return (
    <>
      <AppHeader />
      <CategoriesGrid />
    </>
  );
}

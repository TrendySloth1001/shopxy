import { z } from "zod";
import { zNum } from "@/shared/zod";

export const invitationShopSchema = z
  .object({
    id: z.coerce.string(),
    name: z.string(),
    slug: z.string().nullish(),
    logoUrl: z.string().nullish(),
    bannerUrl: z.string().nullish(),
  })
  .passthrough();

export const invitationFromUserSchema = z
  .object({
    id: z.coerce.string(),
    name: z.string().nullish(),
    email: z.string().nullish(),
    avatarUrl: z.string().nullish(),
  })
  .passthrough();

export const invitationSchema = z
  .object({
    id: z.coerce.string(),
    shopId: z.coerce.string().nullish(),
    fromUserId: z.coerce.string().nullish(),
    toEmail: z.string().nullish(),
    toUserId: z.coerce.string().nullish(),
    linkType: z.enum(["PARTY", "VENDOR", "TEAM"]).nullish(),
    teamRole: z.string().nullish(),
    teamRoleName: z.string().nullish(),
    partyId: z.coerce.string().nullish(),
    vendorId: z.coerce.string().nullish(),
    status: z.enum(["PENDING", "ACCEPTED", "DECLINED", "CANCELLED", "EXPIRED"]),
    message: z.string().nullish(),
    fromShopName: z.string().nullish(),
    displayName: z.string().nullish(),
    expiresAt: z.string().nullish(),
    respondedAt: z.string().nullish(),
    createdAt: z.string(),
    updatedAt: z.string().nullish(),
    fromUser: invitationFromUserSchema.nullish(),
    shop: invitationShopSchema.nullish(),
    party: z.object({ id: z.coerce.string(), name: z.string(), email: z.string().nullish() }).nullish(),
    vendor: z.object({ id: z.coerce.string(), name: z.string(), email: z.string().nullish() }).nullish(),
  })
  .passthrough();
export type Invitation = z.infer<typeof invitationSchema>;

export const invitationPageSchema = z.object({
  data: z.array(invitationSchema).nullish().transform((v) => v ?? []),
  total: z.coerce.number().default(0),
  page: z.coerce.number().default(1),
  limit: z.coerce.number().default(20),
  skip: z.coerce.number().default(0),
});
export type InvitationPage = z.infer<typeof invitationPageSchema>;

export const linkedShopSchema = z
  .object({
    id: z.coerce.string(),
    ownerUserId: z.coerce.string().nullish(),
    name: z.string(),
    slug: z.string().nullish(),
    tagline: z.string().nullish(),
    logoUrl: z.string().nullish(),
    bannerUrl: z.string().nullish(),
    isPublished: z.boolean().nullish(),
    rating: zNum.nullish(),
    ratingCount: z.number().nullish(),
    roles: z
      .object({ party: z.boolean().default(false), vendor: z.boolean().default(false) })
      .nullish(),
  })
  .passthrough();
export type LinkedShop = z.infer<typeof linkedShopSchema>;

export const linkedShopsResponseSchema = z.object({
  data: z.array(linkedShopSchema).nullish().transform((v) => v ?? []),
});

const invoiceSummarySchema = z.object({
  invoiceDate: z.string().nullish(),
  total: zNum.nullish(),
});

const linkShopMiniSchema = z
  .object({
    id: z.coerce.string().nullish(),
    name: z.string().nullish(),
    slug: z.string().nullish(),
    logoUrl: z.string().nullish(),
    bannerUrl: z.string().nullish(),
  })
  .passthrough()
  .nullish();

export const partySchema = z
  .object({
    id: z.coerce.string(),
    name: z.string(),
    email: z.string().nullish(),
    phone: z.string().nullish(),
    address: z.string().nullish(),
    _count: z.object({ invoices: z.coerce.number().default(0) }).nullish(),
    shop: linkShopMiniSchema,
    invoices: z.array(invoiceSummarySchema).nullish(),
  })
  .passthrough();
export type Party = z.infer<typeof partySchema>;

export const vendorSchema = z
  .object({
    id: z.coerce.string(),
    name: z.string(),
    email: z.string().nullish(),
    phone: z.string().nullish(),
    address: z.string().nullish(),
    _count: z.object({ invoices: z.coerce.number().default(0) }).nullish(),
    shop: linkShopMiniSchema,
    invoices: z.array(invoiceSummarySchema).nullish(),
  })
  .passthrough();
export type Vendor = z.infer<typeof vendorSchema>;

export const linksResponseSchema = z.object({
  parties: z.array(partySchema).nullish().transform((v) => v ?? []),
  vendors: z.array(vendorSchema).nullish().transform((v) => v ?? []),
});
export type LinksResponse = z.infer<typeof linksResponseSchema>;

const categorySchema = z
  .object({
    id: z.coerce.string(),
    name: z.string(),
    imageUrl: z.string().nullish(),
    iconName: z.string().nullish(),
    _count: z.object({ products: z.coerce.number().default(0) }).nullish(),
  })
  .passthrough();
export type CatalogCategory = z.infer<typeof categorySchema>;

export const catalogCategoriesSchema = z.array(categorySchema);

const productImageSchema = z.object({
  id: z.coerce.string(),
  url: z.string(),
  sortOrder: z.number().nullish(),
});

export const catalogProductSchema = z
  .object({
    id: z.coerce.string(),
    name: z.string(),
    description: z.string().nullish(),
    sku: z.string().nullish(),
    hsnCode: z.string().nullish(),
    unit: z.string().nullish(),
    mrp: zNum.nullish(),
    sellingPrice: zNum.nullish(),
    taxPercent: zNum.nullish(),
    stockQuantity: zNum.nullish(),
    categoryId: z.coerce.string().nullish(),
    category: z.object({ id: z.coerce.string(), name: z.string(), iconName: z.string().nullish() }).nullish(),
    images: z.array(productImageSchema).nullish().transform((v) => v ?? []),
  })
  .passthrough();
export type CatalogProduct = z.infer<typeof catalogProductSchema>;

export const catalogProductsPageSchema = z.object({
  data: z.array(catalogProductSchema).nullish().transform((v) => v ?? []),
  total: z.coerce.number().default(0),
  page: z.coerce.number().default(1),
  limit: z.coerce.number().default(20),
  skip: z.coerce.number().default(0),
});
export type CatalogProductsPage = z.infer<typeof catalogProductsPageSchema>;

export type MerchantRole = "party" | "vendor";

export function parseMerchantRole(raw: string): MerchantRole | null {
  if (raw === "party" || raw === "vendor") return raw;
  return null;
}

export function roleLabelOf(role: MerchantRole): string {
  return role === "party" ? "Customer" : "Supplier";
}

export function roleColorOf(role: MerchantRole): string {
  return role === "party" ? "bg-brand-soft text-brand" : "bg-accent-indigo-soft text-accent-indigo";
}

export function merchantBase(role: MerchantRole, id: string): string {
  return `/merchants/${role}/${id}`;
}

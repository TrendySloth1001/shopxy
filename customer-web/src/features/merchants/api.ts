/**
 * Client-side fetchers for the merchants / invitations feature.
 * All calls go to /api/* BFF routes (never the backend directly).
 */

import {
  invitationPageSchema,
  invitationSchema,
  linksResponseSchema,
  linkedShopsResponseSchema,
  catalogCategoriesSchema,
  catalogProductsPageSchema,
  type InvitationPage,
  type Invitation,
  type LinksResponse,
  type LinkedShop,
  type CatalogCategory,
  type CatalogProductsPage,
} from "./types";

// ─── Shared helpers ────────────────────────────────────────────────────────

async function jsonOrThrow<T>(
  res: Response,
  parse: (raw: unknown) => T,
  fallback: string,
): Promise<T> {
  if (!res.ok) {
    let message = fallback;
    try {
      const b = (await res.json()) as { error?: string };
      if (b?.error) message = b.error;
    } catch {
      /* keep fallback */
    }
    throw new Error(message);
  }
  return parse(await res.json());
}

// ─── Invitations ───────────────────────────────────────────────────────────

export async function fetchIncomingInvitations(opts?: {
  status?: string;
  page?: number;
  limit?: number;
}): Promise<InvitationPage> {
  const qs = new URLSearchParams();
  if (opts?.status) qs.set("status", opts.status);
  qs.set("page", String(opts?.page ?? 1));
  qs.set("limit", String(opts?.limit ?? 50));
  const res = await fetch(`/api/invitations/incoming?${qs}`, { cache: "no-store" });
  return jsonOrThrow(
    res,
    (raw) => invitationPageSchema.parse(raw),
    "Could not load invitations.",
  );
}

export async function acceptInvitation(id: string): Promise<Invitation> {
  const res = await fetch(`/api/invitations/${id}/accept`, { method: "POST" });
  return jsonOrThrow(
    res,
    (raw) => invitationSchema.parse(raw),
    "Could not accept invitation.",
  );
}

export async function declineInvitation(id: string): Promise<Invitation> {
  const res = await fetch(`/api/invitations/${id}/decline`, { method: "POST" });
  return jsonOrThrow(
    res,
    (raw) => invitationSchema.parse(raw),
    "Could not decline invitation.",
  );
}

// ─── Links / merchants hub ─────────────────────────────────────────────────

export async function fetchLinks(): Promise<LinksResponse> {
  const res = await fetch("/api/me/links", { cache: "no-store" });
  return jsonOrThrow(
    res,
    (raw) => linksResponseSchema.parse(raw),
    "Could not load your merchants.",
  );
}

export async function fetchLinkedShops(): Promise<LinkedShop[]> {
  const res = await fetch("/api/me/linked-shops", { cache: "no-store" });
  return jsonOrThrow(
    res,
    (raw) => linkedShopsResponseSchema.parse(raw).data,
    "Could not load linked shops.",
  );
}

// ─── Catalog ───────────────────────────────────────────────────────────────

export async function fetchCatalogCategories(): Promise<CatalogCategory[]> {
  const res = await fetch("/api/me/catalog/categories", { cache: "no-store" });
  return jsonOrThrow(
    res,
    (raw) => catalogCategoriesSchema.parse(raw),
    "Could not load categories.",
  );
}

export async function fetchCatalogProducts(opts?: {
  search?: string;
  categoryId?: string;
  page?: number;
  limit?: number;
}): Promise<CatalogProductsPage> {
  const qs = new URLSearchParams();
  if (opts?.search) qs.set("search", opts.search);
  if (opts?.categoryId) qs.set("categoryId", String(opts.categoryId));
  qs.set("page", String(opts?.page ?? 1));
  qs.set("limit", String(opts?.limit ?? 24));
  const res = await fetch(`/api/me/catalog/products?${qs}`, { cache: "no-store" });
  return jsonOrThrow(
    res,
    (raw) => catalogProductsPageSchema.parse(raw),
    "Could not load products.",
  );
}

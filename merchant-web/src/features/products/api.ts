import type {
  Category,
  CustomFieldDef,
  CustomFieldValue,
  Product,
  ProductImage,
  ProductList,
} from "./schema";

/** Payload sent to create/update — assembled by the form, validated by the backend. */
export type ProductWritePayload = Record<string, unknown>;

async function jsonOrThrow<T>(res: Response, fallback: string): Promise<T> {
  if (!res.ok) {
    let message = fallback;
    try {
      const body = (await res.json()) as { error?: string };
      if (body?.error) message = body.error;
    } catch {
      // keep fallback
    }
    throw new Error(message);
  }
  return (await res.json()) as T;
}

export function listProducts(
  query: Record<string, string>,
): Promise<ProductList> {
  const qs = new URLSearchParams(query).toString();
  return fetch(`/api/products${qs ? `?${qs}` : ""}`, { cache: "no-store" }).then(
    (r) => jsonOrThrow<ProductList>(r, "Could not load products."),
  );
}

export function getProduct(id: number): Promise<Product> {
  return fetch(`/api/products/${id}`, { cache: "no-store" }).then((r) =>
    jsonOrThrow<Product>(r, "Could not load the product."),
  );
}

export function createProduct(payload: ProductWritePayload): Promise<Product> {
  return fetch("/api/products", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  }).then((r) => jsonOrThrow<Product>(r, "Could not create the product."));
}

export function updateProduct(
  id: number,
  payload: ProductWritePayload,
): Promise<Product> {
  return fetch(`/api/products/${id}`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  }).then((r) => jsonOrThrow<Product>(r, "Could not save the product."));
}

export async function deleteProduct(id: number): Promise<void> {
  const res = await fetch(`/api/products/${id}`, { method: "DELETE" });
  if (!res.ok && res.status !== 204) {
    await jsonOrThrow(res, "Could not delete the product.");
  }
}

export function setPublished(
  id: number,
  isPublished: boolean,
): Promise<Product> {
  return fetch(`/api/products/${id}/publish`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ isPublished }),
  }).then((r) => jsonOrThrow<Product>(r, "Could not update publish state."));
}

export function addImage(id: number, url: string): Promise<ProductImage> {
  return fetch(`/api/products/${id}/images`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ url }),
  }).then((r) => jsonOrThrow<ProductImage>(r, "Could not add the image."));
}

export async function deleteImage(id: number, imageId: number): Promise<void> {
  const res = await fetch(`/api/products/${id}/images/${imageId}`, {
    method: "DELETE",
  });
  if (!res.ok && res.status !== 204) {
    await jsonOrThrow(res, "Could not remove the image.");
  }
}

export function reorderImages(
  id: number,
  orderedIds: number[],
): Promise<ProductImage[]> {
  return fetch(`/api/products/${id}/images/reorder`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ orderedIds }),
  }).then((r) => jsonOrThrow<ProductImage[]>(r, "Could not reorder images."));
}

/** Upload an image file; returns the stored relative URL. */
export async function uploadImage(file: File): Promise<string> {
  const form = new FormData();
  form.append("file", file);
  const res = await fetch("/api/upload", { method: "POST", body: form });
  const body = await jsonOrThrow<{ url: string }>(res, "Upload failed.");
  return body.url;
}

export function listCategories(): Promise<Category[]> {
  return fetch("/api/categories", { cache: "no-store" }).then((r) =>
    jsonOrThrow<Category[]>(r, "Could not load categories."),
  );
}

export function listCustomFieldDefs(): Promise<CustomFieldDef[]> {
  return fetch("/api/custom-fields", { cache: "no-store" }).then((r) =>
    jsonOrThrow<CustomFieldDef[]>(r, "Could not load custom fields."),
  );
}

export function getProductCustomFields(
  id: number,
): Promise<CustomFieldValue[]> {
  return fetch(`/api/products/${id}/custom-fields`, { cache: "no-store" }).then(
    (r) => jsonOrThrow<CustomFieldValue[]>(r, "Could not load custom fields."),
  );
}

export async function saveProductCustomFields(
  id: number,
  values: Array<{ definitionId: number; value: string }>,
): Promise<void> {
  const res = await fetch(`/api/products/${id}/custom-fields`, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ values }),
  });
  if (!res.ok) await jsonOrThrow(res, "Could not save custom fields.");
}

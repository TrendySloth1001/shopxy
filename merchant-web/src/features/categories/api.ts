import {
  categoryDetailSchema,
  categoryTreeSchema,
  type CategoryBase,
  type CategoryNode,
} from "./schema";

async function jsonOrThrow<T>(res: Response, parse: (raw: unknown) => T, fallback: string): Promise<T> {
  if (!res.ok) {
    let message = fallback;
    try {
      const body = (await res.json()) as { error?: string };
      if (body?.error) message = body.error;
    } catch {
      /* keep fallback */
    }
    throw new Error(message);
  }
  return parse(await res.json());
}

/** The active taxonomy as a tree of root nodes (each with nested children). */
export function getCategoryTree(): Promise<CategoryNode[]> {
  return fetch("/api/categories/tree", { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => categoryTreeSchema.parse(raw).data, "Could not load categories."),
  );
}

export function getCategory(id: string): Promise<CategoryBase> {
  return fetch(`/api/categories/${id}`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => categoryDetailSchema.parse(raw), "Could not load the category."),
  );
}

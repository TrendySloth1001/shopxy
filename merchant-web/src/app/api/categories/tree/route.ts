import { proxy } from "@/server/proxy";

// GET /api/categories/tree → /categories/tree?active=true (merchant browse).
export function GET() {
  return proxy("/categories/tree?active=true", undefined, {
    method: "GET",
    fallback: "Could not load categories.",
  });
}

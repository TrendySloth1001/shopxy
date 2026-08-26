import { proxy } from "@/server/proxy";

export function GET() {
  return proxy("/categories/tree?active=true", undefined, {
    method: "GET",
    fallback: "Could not load categories.",
  });
}

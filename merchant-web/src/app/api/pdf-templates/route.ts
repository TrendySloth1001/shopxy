import { proxy } from "@/server/proxy";

export function GET() {
  return proxy("/pdf-templates", undefined, { fallback: "Could not load templates." });
}

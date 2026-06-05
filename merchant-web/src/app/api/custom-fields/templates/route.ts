import { proxy } from "@/server/proxy";

export function GET() {
  return proxy("/custom-fields/templates", undefined, {
    fallback: "Could not load templates.",
  });
}

import { proxy } from "@/server/proxy";

export function GET() {
  return proxy("/numbering", undefined, { fallback: "Could not load numbering settings." });
}

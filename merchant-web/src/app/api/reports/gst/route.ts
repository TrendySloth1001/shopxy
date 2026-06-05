import { proxy, withQuery } from "@/server/proxy";

export function GET(req: Request) {
  return proxy(withQuery("/reports/gst", req), req, { fallback: "Could not load the GST report." });
}

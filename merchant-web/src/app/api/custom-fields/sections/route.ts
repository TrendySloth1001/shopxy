import { proxy, withQuery } from "@/server/proxy";

export function GET(req: Request) {
  return proxy(withQuery("/custom-fields/sections", req), undefined, {
    fallback: "Could not load sections.",
  });
}

export function POST(req: Request) {
  return proxy("/custom-fields/sections", req, {
    fallback: "Could not create the section.",
  });
}

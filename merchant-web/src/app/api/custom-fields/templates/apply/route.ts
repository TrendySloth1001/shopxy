import { proxy } from "@/server/proxy";

export function POST(req: Request) {
  return proxy("/custom-fields/templates/apply", req, {
    fallback: "Could not apply the template.",
  });
}

import { proxy } from "@/server/proxy";

export function GET() {
  return proxy("/me/team/roles", undefined, { fallback: "Could not load roles." });
}

export function POST(req: Request) {
  return proxy("/me/team/roles", req, { fallback: "Could not create the role." });
}

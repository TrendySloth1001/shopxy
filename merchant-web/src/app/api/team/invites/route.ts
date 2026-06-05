import { proxy } from "@/server/proxy";

export function GET() {
  return proxy("/me/team/invites", undefined, { fallback: "Could not load invites." });
}

export function POST(req: Request) {
  return proxy("/me/team/invites", req, { fallback: "Could not send the invite." });
}

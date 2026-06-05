import { proxy } from "@/server/proxy";

export function GET() {
  return proxy("/me/team/members", undefined, { fallback: "Could not load the team." });
}

import { proxyPublic } from "@/server/bff";

/** GET /search/hints — trending search terms. Public, Redis-cached 5 min. */
export async function GET() {
  return proxyPublic("/search/hints", undefined, "Could not load search hints.");
}

import { proxyPublic } from "@/server/bff";

export async function GET() {
  return proxyPublic("/search/hints", undefined, "Could not load search hints.");
}

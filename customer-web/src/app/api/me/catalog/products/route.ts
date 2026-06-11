import { proxyAuthed } from "@/server/bff";

/** GET /me/catalog/products — linked shop catalog product list. Auth required. */
export async function GET(req: Request) {
  const qs = new URL(req.url).searchParams.toString();
  return proxyAuthed(
    `/me/catalog/products${qs ? `?${qs}` : ""}`,
    undefined,
    "Could not load catalog.",
  );
}

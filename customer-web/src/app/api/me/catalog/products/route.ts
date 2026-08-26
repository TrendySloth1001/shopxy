import { proxyAuthed } from "@/server/bff";

export async function GET(req: Request) {
  const qs = new URL(req.url).searchParams.toString();
  return proxyAuthed(
    `/me/catalog/products${qs ? `?${qs}` : ""}`,
    undefined,
    "Could not load catalog.",
  );
}

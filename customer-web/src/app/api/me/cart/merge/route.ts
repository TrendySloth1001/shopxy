import { proxyAuthed } from "@/server/bff";

export async function POST(req: Request) {
  const body = await req.json().catch(() => null);
  return proxyAuthed(
    "/me/cart/merge",
    { method: "POST", body: JSON.stringify(body) },
    "Could not merge cart.",
  );
}

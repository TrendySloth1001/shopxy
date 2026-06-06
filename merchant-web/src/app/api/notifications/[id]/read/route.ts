import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

/** Mark a single notification read. */
export async function POST(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/notifications/${encodeURIComponent(id)}/read`, req, {
    fallback: "Could not mark it read.",
  });
}

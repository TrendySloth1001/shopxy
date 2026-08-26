import { proxy } from "@/server/proxy";

export async function GET(req: Request, ctx: { params: Promise<{ id: string }> }) {
  const { id } = await ctx.params;
  return proxy(`/me/cashier/shifts/${encodeURIComponent(id)}/report`, req, {
    fallback: "Could not load the Z-report.",
  });
}

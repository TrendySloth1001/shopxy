import { proxy } from "@/server/proxy";

export async function GET(req: Request, ctx: { params: Promise<{ invoiceId: string }> }) {
  const { invoiceId } = await ctx.params;
  return proxy(`/me/cashier/returnable/${encodeURIComponent(invoiceId)}`, req, {
    fallback: "Could not load the sale.",
  });
}

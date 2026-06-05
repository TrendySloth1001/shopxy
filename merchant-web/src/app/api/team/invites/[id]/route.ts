import { proxy } from "@/server/proxy";

export async function DELETE(
  _req: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;
  return proxy(`/me/team/invites/${encodeURIComponent(id)}`, undefined, {
    method: "DELETE",
    fallback: "Could not cancel the invite.",
  });
}

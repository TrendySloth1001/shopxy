import { proxy } from "@/server/proxy";

export async function PATCH(
  req: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;
  return proxy(`/me/team/roles/${encodeURIComponent(id)}`, req, {
    fallback: "Could not save the role.",
  });
}

export async function DELETE(
  _req: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;
  return proxy(`/me/team/roles/${encodeURIComponent(id)}`, undefined, {
    method: "DELETE",
    fallback: "Could not delete the role.",
  });
}

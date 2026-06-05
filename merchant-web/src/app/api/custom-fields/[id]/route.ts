import { proxy } from "@/server/proxy";

export async function PATCH(
  req: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;
  return proxy(`/custom-fields/${encodeURIComponent(id)}`, req, {
    fallback: "Could not save the field.",
  });
}

export async function DELETE(
  _req: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;
  return proxy(`/custom-fields/${encodeURIComponent(id)}`, undefined, {
    method: "DELETE",
    fallback: "Could not delete the field.",
  });
}

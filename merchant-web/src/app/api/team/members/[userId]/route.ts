import { proxy } from "@/server/proxy";

export async function DELETE(
  _req: Request,
  { params }: { params: Promise<{ userId: string }> },
) {
  const { userId } = await params;
  return proxy(`/me/team/members/${encodeURIComponent(userId)}`, undefined, {
    method: "DELETE",
    fallback: "Could not remove the member.",
  });
}

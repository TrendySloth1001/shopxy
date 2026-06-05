import { proxy } from "@/server/proxy";

export async function PATCH(
  req: Request,
  { params }: { params: Promise<{ userId: string }> },
) {
  const { userId } = await params;
  return proxy(`/me/team/members/${encodeURIComponent(userId)}/permissions`, req, {
    fallback: "Could not update permissions.",
  });
}

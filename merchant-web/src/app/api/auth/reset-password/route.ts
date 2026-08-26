import { NextResponse } from "next/server";
import { z } from "zod";
import { backendFetch } from "@/server/auth/session";

const bodySchema = z.object({
  email: z.string().trim().email(),
  otp: z.string().trim().regex(/^\d{6}$/),
  newPassword: z
    .string()
    .min(10, "Password must be at least 10 characters")
    .max(128)
    .regex(/[A-Za-z]/, "Password must contain at least one letter")
    .regex(/[0-9]/, "Password must contain at least one number"),
});

export async function POST(req: Request) {
  const json = await req.json().catch(() => null);
  const parsed = bodySchema.safeParse(json);
  if (!parsed.success) {
    const first = parsed.error.issues[0]?.message ?? "Please check the form and try again.";
    return NextResponse.json({ error: first }, { status: 400 });
  }

  const res = await backendFetch("/auth/reset-password", {
    method: "POST",
    body: JSON.stringify(parsed.data),
  });
  if (!res.ok) {
    const body = (await res.json().catch(() => null)) as
      | { error?: string; message?: string }
      | null;
    return NextResponse.json(
      { error: body?.message ?? body?.error ?? "Could not reset your password." },
      { status: res.status === 400 ? 400 : 401 },
    );
  }
  return new NextResponse(null, { status: 204 });
}

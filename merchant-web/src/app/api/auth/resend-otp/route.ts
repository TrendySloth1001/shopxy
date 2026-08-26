import { NextResponse } from "next/server";
import { z } from "zod";
import { backendFetch, extractError } from "@/server/auth/session";

const bodySchema = z.object({ email: z.string().trim().email() });

export async function POST(req: Request) {
  const json = await req.json().catch(() => null);
  const parsed = bodySchema.safeParse(json);
  if (!parsed.success) {
    return NextResponse.json({ error: "Invalid request." }, { status: 400 });
  }

  const res = await backendFetch("/auth/resend-otp", {
    method: "POST",
    body: JSON.stringify({ email: parsed.data.email }),
  });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not send a new code.") },
      { status: res.status === 429 ? 429 : 400 },
    );
  }
  return new NextResponse(null, { status: 204 });
}

import { NextResponse } from "next/server";
import { z } from "zod";
import { backendFetch } from "@/server/auth/session";

const bodySchema = z.object({ email: z.string().trim().email() });

export async function POST(req: Request) {
  const json = await req.json().catch(() => null);
  const parsed = bodySchema.safeParse(json);
  if (!parsed.success) {
    return NextResponse.json({ error: "Enter a valid email address." }, { status: 400 });
  }

  try {
    await backendFetch("/auth/forgot-password", {
      method: "POST",
      body: JSON.stringify({ email: parsed.data.email }),
    });
  } catch {
  }
  return new NextResponse(null, { status: 204 });
}

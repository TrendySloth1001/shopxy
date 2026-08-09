import { NextResponse } from "next/server";
import { z } from "zod";
import { backendFetch } from "@/server/auth/session";

const bodySchema = z.object({ email: z.string().trim().email() });

/**
 * POST /api/auth/forgot-password — ask the backend to email a reset code.
 *
 * Always 204, mirroring the backend. Even a backend failure is reported as
 * success: any observable difference between "sent" and "no such account"
 * turns this into an account-enumeration oracle, and that's worth more than
 * telling the caller about an outage they can't act on. Server-side logs
 * carry the real outcome.
 */
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
    // Deliberately swallowed — see above.
  }
  return new NextResponse(null, { status: 204 });
}

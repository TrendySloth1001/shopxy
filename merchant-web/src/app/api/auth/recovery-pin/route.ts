import { NextResponse } from "next/server";
import { recoveryPinSchema } from "@/features/auth/schema";
import { authedFetch, extractError } from "@/server/auth/session";

export async function POST(req: Request) {
  const json = await req.json().catch(() => null);
  const parsed = recoveryPinSchema.safeParse((json as { pin?: unknown } | null)?.pin);
  if (!parsed.success) {
    return NextResponse.json({ error: "PIN must be 4-6 digits" }, { status: 400 });
  }

  const res = await authedFetch("/auth/recovery-pin", {
    method: "POST",
    body: JSON.stringify({ pin: parsed.data }),
  });
  if (!res) return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not save your PIN.") },
      { status: 400 },
    );
  }

  return NextResponse.json({ ok: true });
}

import { NextResponse } from "next/server";
import { deleteAccountSchema, updateProfileSchema } from "@/features/auth/schema";
import { authUserSchema } from "@/features/auth/types";
import {
  authedFetch,
  clearSessionCookies,
  extractError,
  getCurrentUser,
} from "@/server/auth/session";

export async function GET() {
  const user = await getCurrentUser();
  if (!user) {
    return NextResponse.json({ user: null }, { status: 401 });
  }
  return NextResponse.json({ user });
}

const CLEARABLE = [
  "shopName",
  "shopAddress",
  "shopCity",
  "shopState",
  "shopStateCode",
  "shopPinCode",
  "shopGstin",
  "gstEffectiveFrom",
  "shopPan",
  "upiVpa",
  "phoneNumber",
] as const;

export async function PATCH(req: Request) {
  const json = await req.json().catch(() => null);
  const parsed = updateProfileSchema.safeParse(json);
  if (!parsed.success) {
    return NextResponse.json(
      { error: parsed.error.issues[0]?.message ?? "Invalid input." },
      { status: 400 },
    );
  }

  const body: Record<string, unknown> = { ...parsed.data };
  for (const key of CLEARABLE) {
    if (key in body && body[key] === "") body[key] = null;
  }

  const res = await authedFetch("/auth/me", {
    method: "PATCH",
    body: JSON.stringify(body),
  });
  if (!res) return NextResponse.json({ user: null }, { status: 401 });
  if (!res.ok) {
    const code = await extractError(res, "Could not save your changes.");
    const message =
      code === "GST_EFFECTIVE_DATE_REQUIRED"
        ? "Pick the date GST starts applying before saving a new GSTIN."
        : code;
    return NextResponse.json({ error: message }, { status: 400 });
  }

  const enriched = await getCurrentUser();
  if (enriched) return NextResponse.json({ user: enriched });
  const fallback = authUserSchema.safeParse(await res.json());
  return NextResponse.json({ user: fallback.success ? fallback.data : null });
}

export async function DELETE(req: Request) {
  const json = await req.json().catch(() => null);
  const parsed = deleteAccountSchema.safeParse(json);
  if (!parsed.success) {
    return NextResponse.json(
      { error: "Enter your password to confirm." },
      { status: 400 },
    );
  }

  const res = await authedFetch("/auth/me", {
    method: "DELETE",
    body: JSON.stringify(parsed.data),
  });
  if (!res) return NextResponse.json({ error: "Session expired." }, { status: 401 });

  if (!res.ok) {
    const body = (await res.json().catch(() => ({}))) as { error?: string };
    if (body.error === "cannot_delete_with_active_records") {
      return NextResponse.json(
        {
          error:
            "This account has invoices that must be retained for 8 years (Companies Act / GST). Contact support to request a controlled deletion.",
        },
        { status: 409 },
      );
    }
    if (body.error === "invalid_password") {
      return NextResponse.json(
        { error: "That password is incorrect." },
        { status: 400 },
      );
    }
    return NextResponse.json(
      { error: "Could not delete your account." },
      { status: 400 },
    );
  }

  const body = (await res.json().catch(() => ({}))) as { mode?: string };
  await clearSessionCookies();
  return NextResponse.json({ ok: true, mode: body.mode ?? "deleted" });
}

import { NextResponse } from "next/server";
import {
  authedFetch,
  extractError,
  getCurrentUser,
} from "@/server/auth/session";

const MAX_BYTES = 8 * 1024 * 1024; // 8 MB — matches the backend limit
const ALLOWED = new Set(["image/jpeg", "image/png", "image/webp"]);

// POST /api/auth/avatar — multipart upload. Forwards the image to the backend
// avatar service, then PATCHes the returned URL onto the profile. Returns the
// updated user so the client re-renders in one round trip.
export async function POST(req: Request) {
  const form = await req.formData().catch(() => null);
  const file = form?.get("file");
  if (!(file instanceof File)) {
    return NextResponse.json({ error: "No image selected." }, { status: 400 });
  }
  if (file.size > MAX_BYTES) {
    return NextResponse.json(
      { error: "Image must be 8 MB or smaller." },
      { status: 400 },
    );
  }
  if (file.type && !ALLOWED.has(file.type)) {
    return NextResponse.json(
      { error: "Use a JPEG, PNG or WebP image." },
      { status: 400 },
    );
  }

  const upstream = new FormData();
  upstream.append("file", file, file.name || "avatar");
  const uploadRes = await authedFetch("/me/upload/avatar", {
    method: "POST",
    body: upstream,
  });
  if (!uploadRes)
    return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!uploadRes.ok) {
    return NextResponse.json(
      { error: await extractError(uploadRes, "Could not upload the image.") },
      { status: 400 },
    );
  }
  const uploaded = (await uploadRes.json().catch(() => ({}))) as {
    url?: string;
  };
  if (!uploaded.url) {
    return NextResponse.json(
      { error: "Upload service returned no image." },
      { status: 502 },
    );
  }

  const patchRes = await authedFetch("/auth/me", {
    method: "PATCH",
    body: JSON.stringify({ avatarUrl: uploaded.url }),
  });
  if (!patchRes)
    return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!patchRes.ok) {
    return NextResponse.json(
      { error: await extractError(patchRes, "Could not save your photo.") },
      { status: 400 },
    );
  }

  const user = await getCurrentUser();
  return NextResponse.json({ user });
}

// DELETE /api/auth/avatar — clear the profile photo.
export async function DELETE() {
  const res = await authedFetch("/auth/me", {
    method: "PATCH",
    body: JSON.stringify({ avatarUrl: null }),
  });
  if (!res)
    return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not remove your photo.") },
      { status: 400 },
    );
  }
  const user = await getCurrentUser();
  return NextResponse.json({ user });
}

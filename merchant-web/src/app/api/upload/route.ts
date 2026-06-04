import { NextResponse } from "next/server";
import { authedFetch, extractError } from "@/server/auth/session";

const MAX_BYTES = 8 * 1024 * 1024;
const ALLOWED = new Set(["image/jpeg", "image/png", "image/webp"]);

// POST /api/upload — multipart image upload, forwarded to the backend /upload
// service. Returns the stored (relative) URL.
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
  upstream.append("file", file, file.name || "image");
  const res = await authedFetch("/upload", { method: "POST", body: upstream });
  if (!res) return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Upload failed.") },
      { status: res.status },
    );
  }
  const body = (await res.json().catch(() => ({}))) as { url?: string };
  if (!body.url) {
    return NextResponse.json(
      { error: "Upload service returned no image." },
      { status: 502 },
    );
  }
  return NextResponse.json({ url: body.url }, { status: 201 });
}

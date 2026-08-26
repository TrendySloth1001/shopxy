import "server-only";
import { NextResponse } from "next/server";
import { authedFetch, backendFetch, extractError } from "@/server/auth/session";

type Init = Omit<RequestInit, "cache">;

export async function proxyPublic(
  backendPath: string,
  init?: Init,
  fallback = "Something went wrong.",
): Promise<NextResponse> {
  const res = await backendFetch(backendPath, init);
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, fallback) },
      { status: res.status },
    );
  }
  return NextResponse.json(await res.json().catch(() => null), {
    status: res.status,
  });
}

export async function proxyAuthed(
  backendPath: string,
  init?: Init,
  fallback = "Something went wrong.",
): Promise<NextResponse> {
  const res = await authedFetch(backendPath, init);
  if (!res)
    return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, fallback) },
      { status: res.status },
    );
  }
  const body = await res.json().catch(() => null);
  return NextResponse.json(body, { status: res.status });
}

export async function proxyAuthedPassthrough(
  backendPath: string,
  init?: Init,
): Promise<NextResponse> {
  const res = await authedFetch(backendPath, init);
  if (!res)
    return NextResponse.json({ error: "Session expired." }, { status: 401 });
  const body = await res.json().catch(() => null);
  return NextResponse.json(body, { status: res.status });
}

export async function proxyAuthed204(
  backendPath: string,
  init?: Init,
  fallback = "Something went wrong.",
): Promise<NextResponse> {
  const res = await authedFetch(backendPath, init);
  if (!res)
    return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, fallback) },
      { status: res.status },
    );
  }
  return new NextResponse(null, { status: 204 });
}

export async function proxyBinaryAuthed(
  backendPath: string,
  fallback = "Could not retrieve file.",
): Promise<NextResponse> {
  const res = await authedFetch(backendPath);
  if (!res)
    return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, fallback) },
      { status: res.status },
    );
  }
  if (!res.body) {
    return NextResponse.json({ error: fallback }, { status: 502 });
  }
  return new NextResponse(res.body, {
    status: res.status,
    headers: {
      "Content-Type":
        res.headers.get("Content-Type") ?? "application/octet-stream",
      "Content-Disposition":
        res.headers.get("Content-Disposition") ?? "attachment",
      "Cache-Control": "private, no-store",
    },
  });
}

export async function proxyAuthedWithBody(
  backendPath: string,
  method: string,
  body: string | null,
  fallback = "Something went wrong.",
): Promise<NextResponse> {
  const init: Init = { method };
  if (body !== null) {
    (init as RequestInit).body = body;
  }
  return proxyAuthed(backendPath, init, fallback);
}

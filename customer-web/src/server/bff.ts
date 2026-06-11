import "server-only";
import { NextResponse } from "next/server";
import { authedFetch, backendFetch, extractError } from "@/server/auth/session";

/**
 * Thin BFF proxy helpers. Each `proxy*` function calls the backend, maps errors
 * to the standard `{ error: string }` envelope and returns a NextResponse.
 *
 * Binary passthrough (PDFs): use `proxyBinaryAuthed` — it streams the upstream
 * body with `Content-Type` and `Content-Disposition` preserved.
 */

type Init = Omit<RequestInit, "cache">;

// ─── public (no session required) ────────────────────────────────────────────

/**
 * Proxy a public GET (or any method) to the backend, forwarding the query
 * string from the incoming request.
 */
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

// ─── authenticated ────────────────────────────────────────────────────────────

/**
 * Proxy a protected endpoint. Returns 401 if no live session.
 */
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

/**
 * Like proxyAuthed but returns 204 (no body) on success. Use for mutations
 * whose backend also responds 204.
 */
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

/**
 * Stream a binary (PDF) response from the backend through to the browser.
 * Preserves Content-Type and Content-Disposition headers.
 */
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

/**
 * Forward the entire incoming request body + query string to the backend.
 * Returns the upstream JSON or binary response as-is.
 */
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

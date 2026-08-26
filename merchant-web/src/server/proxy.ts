import "server-only";
import { NextResponse } from "next/server";
import { authedFetch, extractError } from "./auth/session";

export async function proxy(
  backendPath: string,
  req?: Request,
  opts?: { method?: string; fallback?: string },
): Promise<NextResponse> {
  const method = opts?.method ?? req?.method ?? "GET";

  let body: string | undefined;
  if (req && method !== "GET" && method !== "HEAD") {
    const json = await req.json().catch(() => null);
    if (json != null) body = JSON.stringify(json);
  }

  const res = await authedFetch(backendPath, { method, body });
  if (!res) return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (res.status === 204) return new NextResponse(null, { status: 204 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, opts?.fallback ?? "Request failed.") },
      { status: res.status },
    );
  }
  const data = await res.json().catch(() => null);
  return NextResponse.json(data, { status: res.status });
}

export function withQuery(backendPath: string, req: Request): string {
  const qs = new URL(req.url).searchParams.toString();
  return qs ? `${backendPath}?${qs}` : backendPath;
}

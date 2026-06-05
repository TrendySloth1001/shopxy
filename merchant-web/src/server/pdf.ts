import "server-only";
import { NextResponse } from "next/server";
import { authedFetch, extractError } from "./auth/session";

/**
 * Stream a backend-rendered PDF through the BFF. Unlike `proxy()` (which parses
 * JSON), this passes the binary body and content headers through unchanged so
 * the browser can open / print / save it. `fallbackName` names the file when
 * the backend doesn't send a Content-Disposition.
 */
export async function streamPdf(backendPath: string, fallbackName: string): Promise<NextResponse> {
  const res = await authedFetch(backendPath);
  if (!res) return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not generate the PDF.") },
      { status: res.status },
    );
  }
  const body = await res.arrayBuffer();
  return new NextResponse(body, {
    status: 200,
    headers: {
      "Content-Type": res.headers.get("content-type") ?? "application/pdf",
      "Content-Disposition":
        res.headers.get("content-disposition") ?? `inline; filename="${fallbackName}"`,
    },
  });
}

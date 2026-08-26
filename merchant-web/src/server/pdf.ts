import "server-only";
import { NextResponse } from "next/server";
import { authedFetch, extractError } from "./auth/session";

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

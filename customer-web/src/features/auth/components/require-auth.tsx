"use client";

import { useEffect, type ReactNode } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "../auth-context";

/**
 * Client gate for protected pages. Middleware already blocks cookieless
 * visitors; this handles the case where the cookie exists but the session is
 * actually invalid (expired + refresh failed), and avoids flashing protected
 * content before the session resolves.
 */
export function RequireAuth({ children }: { children: ReactNode }) {
  const { status } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (status === "guest") router.replace("/login");
  }, [status, router]);

  if (status !== "authed") {
    return (
      <div className="flex min-h-dvh items-center justify-center">
        <p className="text-body-md text-subtle">Loading…</p>
      </div>
    );
  }
  return <>{children}</>;
}

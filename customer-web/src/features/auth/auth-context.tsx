"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import type { AuthUser } from "./types";
import type { UpdateProfileInput } from "./schema";

/** Payload the register form sends to the provider (confirm is dropped). */
export type RegisterPayload = {
  name: string;
  email: string;
  password: string;
  acceptedTerms: true;
  acceptedPrivacy: true;
};

export type RegisterOutcome =
  | { pending: true; email: string }
  | { pending: false };

type Status = "loading" | "authed" | "guest";

type AuthContextValue = {
  user: AuthUser | null;
  status: Status;
  login: (email: string, password: string) => Promise<void>;
  /** `{ pending: true }` normally — no account until {@link verifyEmail}. */
  register: (payload: RegisterPayload) => Promise<RegisterOutcome>;
  verifyEmail: (email: string, otp: string) => Promise<void>;
  resendOtp: (email: string) => Promise<void>;
  logout: () => Promise<void>;
  /** Revoke every session (this device included). */
  logoutEverywhere: () => Promise<void>;
  updateProfile: (input: UpdateProfileInput) => Promise<void>;
  /** On success the backend revokes all sessions — the caller must re-auth. */
  changePassword: (currentPassword: string, newPassword: string) => Promise<void>;
  deleteAccount: (currentPassword: string) => Promise<void>;
  uploadAvatar: (file: File) => Promise<void>;
  removeAvatar: () => Promise<void>;
  /** Download the DPDP data export as a file. */
  exportData: () => Promise<void>;
  refresh: () => Promise<void>;
};

const AuthContext = createContext<AuthContextValue | null>(null);

/** Read `{ error }` from a non-OK BFF response and throw it as an Error. */
async function throwApiError(res: Response, fallback: string): Promise<never> {
  let message = fallback;
  try {
    const body = (await res.json()) as { error?: string };
    if (body?.error) message = body.error;
  } catch {
    // keep fallback
  }
  throw new Error(message);
}

export function AuthProvider({
  children,
  initialUser = null,
}: {
  children: ReactNode;
  /** Session resolved server-side (read-only) in the root layout. When set, the
   *  provider starts authed and skips the mount bootstrap fetch. */
  initialUser?: AuthUser | null;
}) {
  const [user, setUser] = useState<AuthUser | null>(initialUser);
  const [status, setStatus] = useState<Status>(initialUser ? "authed" : "loading");

  const refresh = useCallback(async () => {
    const res = await fetch("/api/auth/me", { cache: "no-store" });
    if (res.ok) {
      const body = (await res.json()) as { user: AuthUser };
      setUser(body.user);
      setStatus("authed");
    } else {
      setUser(null);
      setStatus("guest");
    }
  }, []);

  // Bootstrap the session from the httpOnly cookie on mount — but ONLY when the
  // server couldn't already resolve it (no fresh access cookie). When
  // `initialUser` is set we trust the server render and skip this round-trip;
  // `refresh()` stays available for explicit revalidation. State is only set
  // after the await (never synchronously) and is guarded against an unmount
  // race — this is external-system sync, not derived state.
  useEffect(() => {
    if (initialUser) return;
    let active = true;
    void (async () => {
      const res = await fetch("/api/auth/me", { cache: "no-store" });
      if (!active) return;
      if (res.ok) {
        const body = (await res.json()) as { user: AuthUser };
        if (!active) return;
        setUser(body.user);
        setStatus("authed");
      } else {
        setUser(null);
        setStatus("guest");
      }
    })();
    return () => {
      active = false;
    };
  }, [initialUser]);

  const login = useCallback(async (email: string, password: string) => {
    const res = await fetch("/api/auth/login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password }),
    });
    if (!res.ok) await throwApiError(res, "Sign in failed.");
    const body = (await res.json()) as { user: AuthUser };
    setUser(body.user);
    setStatus("authed");
  }, []);

  const register = useCallback(async (payload: RegisterPayload): Promise<RegisterOutcome> => {
    const res = await fetch("/api/auth/register", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    if (!res.ok) await throwApiError(res, "Could not create your account.");
    const body = (await res.json()) as
      | { pending: true; email: string }
      | { user: AuthUser };
    // No account yet — do NOT mark the session authed.
    if ("pending" in body) return { pending: true, email: body.email };
    setUser(body.user);
    setStatus("authed");
    return { pending: false };
  }, []);

  const verifyEmail = useCallback(async (email: string, otp: string) => {
    const res = await fetch("/api/auth/verify-email", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, otp }),
    });
    if (!res.ok) await throwApiError(res, "That code didn't work.");
    const body = (await res.json()) as { user: AuthUser };
    setUser(body.user);
    setStatus("authed");
  }, []);

  const resendOtp = useCallback(async (email: string) => {
    const res = await fetch("/api/auth/resend-otp", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email }),
    });
    if (!res.ok) await throwApiError(res, "Could not send a new code.");
  }, []);

  const logout = useCallback(async () => {
    await fetch("/api/auth/logout", { method: "POST" });
    setUser(null);
    setStatus("guest");
  }, []);

  const logoutEverywhere = useCallback(async () => {
    await fetch("/api/auth/logout-all", { method: "POST" });
    setUser(null);
    setStatus("guest");
  }, []);

  const updateProfile = useCallback(async (input: UpdateProfileInput) => {
    const res = await fetch("/api/auth/me", {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(input),
    });
    if (!res.ok) await throwApiError(res, "Could not save your changes.");
    const body = (await res.json()) as { user: AuthUser };
    setUser(body.user);
    setStatus("authed");
  }, []);

  const changePassword = useCallback(
    async (currentPassword: string, newPassword: string) => {
      const res = await fetch("/api/auth/change-password", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ currentPassword, newPassword }),
      });
      if (!res.ok) await throwApiError(res, "Could not change your password.");
      // All sessions (including this one) are now revoked — drop local state.
      setUser(null);
      setStatus("guest");
    },
    [],
  );

  const deleteAccount = useCallback(async (currentPassword: string) => {
    const res = await fetch("/api/auth/me", {
      method: "DELETE",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ currentPassword }),
    });
    if (!res.ok) await throwApiError(res, "Could not delete your account.");
    setUser(null);
    setStatus("guest");
  }, []);

  const uploadAvatar = useCallback(async (file: File) => {
    const form = new FormData();
    form.append("file", file);
    const res = await fetch("/api/auth/avatar", { method: "POST", body: form });
    if (!res.ok) await throwApiError(res, "Could not upload the image.");
    const body = (await res.json()) as { user: AuthUser };
    setUser(body.user);
    setStatus("authed");
  }, []);

  const removeAvatar = useCallback(async () => {
    const res = await fetch("/api/auth/avatar", { method: "DELETE" });
    if (!res.ok) await throwApiError(res, "Could not remove your photo.");
    const body = (await res.json()) as { user: AuthUser };
    setUser(body.user);
    setStatus("authed");
  }, []);

  const exportData = useCallback(async () => {
    const res = await fetch("/api/auth/export", { cache: "no-store" });
    if (!res.ok) await throwApiError(res, "Could not export your data.");
    const blob = await res.blob();
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "shopxy-data.json";
    document.body.appendChild(a);
    a.click();
    a.remove();
    URL.revokeObjectURL(url);
  }, []);

  const value = useMemo<AuthContextValue>(
    () => ({
      user,
      status,
      login,
      register,
      verifyEmail,
      resendOtp,
      logout,
      logoutEverywhere,
      updateProfile,
      changePassword,
      deleteAccount,
      uploadAvatar,
      removeAvatar,
      exportData,
      refresh,
    }),
    [
      user,
      status,
      login,
      register,
      verifyEmail,
      resendOtp,
      logout,
      logoutEverywhere,
      updateProfile,
      changePassword,
      deleteAccount,
      uploadAvatar,
      removeAvatar,
      exportData,
      refresh,
    ],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within <AuthProvider>");
  return ctx;
}

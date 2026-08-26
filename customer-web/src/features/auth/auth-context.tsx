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
  register: (payload: RegisterPayload) => Promise<RegisterOutcome>;
  verifyEmail: (email: string, otp: string) => Promise<void>;
  resendOtp: (email: string) => Promise<void>;
  logout: () => Promise<void>;
  logoutEverywhere: () => Promise<void>;
  updateProfile: (input: UpdateProfileInput) => Promise<void>;
  changePassword: (currentPassword: string, newPassword: string) => Promise<void>;
  deleteAccount: (currentPassword: string) => Promise<void>;
  uploadAvatar: (file: File) => Promise<void>;
  removeAvatar: () => Promise<void>;
  exportData: () => Promise<void>;
  refresh: () => Promise<void>;
};

const AuthContext = createContext<AuthContextValue | null>(null);

async function throwApiError(res: Response, fallback: string): Promise<never> {
  let message = fallback;
  try {
    const body = (await res.json()) as { error?: string };
    if (body?.error) message = body.error;
  } catch {
  }
  throw new Error(message);
}

export function AuthProvider({
  children,
  initialUser = null,
}: {
  children: ReactNode;
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

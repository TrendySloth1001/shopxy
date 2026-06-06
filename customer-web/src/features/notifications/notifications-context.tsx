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
import { useAuth } from "@/features/auth/auth-context";
import { getUnreadCount } from "./api";

type NotificationsValue = {
  unread: number;
  refresh: () => void;
  setUnread: (n: number) => void;
};

const NotificationsContext = createContext<NotificationsValue | null>(null);

const POLL_MS = 60_000;

/**
 * Holds the unread-notification count for the header bell. Polls every minute
 * and on tab focus, but only while signed in (this provider sits at the app
 * root, above public pages). The unread-count BFF route soft-fails to 0.
 */
export function NotificationsProvider({ children }: { children: ReactNode }) {
  const { status } = useAuth();
  const [unread, setUnread] = useState(0);

  const refresh = useCallback(() => {
    void getUnreadCount()
      .then(setUnread)
      .catch(() => {
        /* keep the previous count on a blip */
      });
  }, []);

  useEffect(() => {
    if (status !== "authed") return;
    refresh();
    const interval = setInterval(refresh, POLL_MS);
    const onFocus = () => refresh();
    window.addEventListener("focus", onFocus);
    return () => {
      clearInterval(interval);
      window.removeEventListener("focus", onFocus);
    };
  }, [status, refresh]);

  // Signed-out → always show 0 (without a setState in the effect above).
  const exposed = status === "authed" ? unread : 0;
  const value = useMemo<NotificationsValue>(
    () => ({ unread: exposed, refresh, setUnread }),
    [exposed, refresh],
  );

  return <NotificationsContext.Provider value={value}>{children}</NotificationsContext.Provider>;
}

export function useNotifications(): NotificationsValue {
  const ctx = useContext(NotificationsContext);
  if (!ctx) throw new Error("useNotifications must be used within <NotificationsProvider>");
  return ctx;
}

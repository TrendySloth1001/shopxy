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
import { getUnreadCount } from "./api";

type NotificationsValue = {
  /** Unread count powering the sidebar bell badge. */
  unread: number;
  /** Re-fetch the unread count from the server. */
  refresh: () => void;
  /** Optimistically set the count (e.g. after mark-read on the page). */
  setUnread: (n: number) => void;
};

const NotificationsContext = createContext<NotificationsValue | null>(null);

const POLL_MS = 60_000;

/**
 * Holds the unread-notification count for the dashboard shell. Polls every
 * minute and re-checks when the tab regains focus, so the bell badge stays
 * roughly live without a realtime channel. Mounted inside the authed
 * dashboard layout; the unread-count BFF route soft-fails to 0.
 */
export function NotificationsProvider({ children }: { children: ReactNode }) {
  const [unread, setUnread] = useState(0);

  const refresh = useCallback(() => {
    void getUnreadCount()
      .then(setUnread)
      .catch(() => {
        /* keep the previous count on a blip */
      });
  }, []);

  useEffect(() => {
    refresh();
    const interval = setInterval(refresh, POLL_MS);
    const onFocus = () => refresh();
    window.addEventListener("focus", onFocus);
    return () => {
      clearInterval(interval);
      window.removeEventListener("focus", onFocus);
    };
  }, [refresh]);

  const value = useMemo<NotificationsValue>(
    () => ({ unread, refresh, setUnread }),
    [unread, refresh],
  );

  return <NotificationsContext.Provider value={value}>{children}</NotificationsContext.Provider>;
}

export function useNotifications(): NotificationsValue {
  const ctx = useContext(NotificationsContext);
  if (!ctx) throw new Error("useNotifications must be used within <NotificationsProvider>");
  return ctx;
}

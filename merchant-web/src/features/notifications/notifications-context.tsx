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
  unread: number;
  refresh: () => void;
  setUnread: (n: number) => void;
};

const NotificationsContext = createContext<NotificationsValue | null>(null);

const POLL_MS = 60_000;

export function NotificationsProvider({ children }: { children: ReactNode }) {
  const [unread, setUnread] = useState(0);

  const refresh = useCallback(() => {
    void getUnreadCount()
      .then(setUnread)
      .catch(() => {
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

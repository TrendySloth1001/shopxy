"use client";

import Script from "next/script";
import { useCallback, useRef } from "react";
import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { GoogleIcon } from "@/shared/icons";
import { useAuth } from "../auth-context";

const GOOGLE_CLIENT_ID = process.env.NEXT_PUBLIC_GOOGLE_CLIENT_ID;

type GoogleAccountsId = {
  initialize: (config: {
    client_id: string;
    callback: (response: { credential: string }) => void;
    ux_mode: "popup";
  }) => void;
  prompt: () => void;
};

declare global {
  interface Window {
    google?: { accounts: { id: GoogleAccountsId } };
  }
}

export function GoogleButton({ onError }: { onError?: (message: string) => void }) {
  const t = useTranslations("auth");
  const router = useRouter();
  const { loginWithGoogle } = useAuth();
  const initialized = useRef(false);

  const handleCredential = useCallback(
    async (response: { credential: string }) => {
      try {
        const { needsPinSetup } = await loginWithGoogle(response.credential);
        router.replace(needsPinSetup ? "/onboarding/recovery-pin" : "/onboarding");
      } catch (err) {
        onError?.(err instanceof Error ? err.message : t("login.failed"));
      }
    },
    [loginWithGoogle, onError, router, t],
  );

  const handleClick = useCallback(() => {
    if (!GOOGLE_CLIENT_ID) {
      onError?.(t("login.googleUnavailable"));
      return;
    }
    if (!window.google) {
      onError?.(t("login.failed"));
      return;
    }
    if (!initialized.current) {
      window.google.accounts.id.initialize({
        client_id: GOOGLE_CLIENT_ID,
        callback: (response) => void handleCredential(response),
        ux_mode: "popup",
      });
      initialized.current = true;
    }
    window.google.accounts.id.prompt();
  }, [handleCredential, onError, t]);

  if (!GOOGLE_CLIENT_ID) return null;

  return (
    <>
      <Script src="https://accounts.google.com/gsi/client" strategy="afterInteractive" />
      <button
        type="button"
        onClick={handleClick}
        className="inline-flex h-12 w-full items-center justify-center gap-sm rounded-full border border-hairline bg-surface text-label-lg text-ink transition-colors hover:border-brand hover:text-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
      >
        <GoogleIcon />
        {t("login.continueWithGoogle")}
      </button>
    </>
  );
}

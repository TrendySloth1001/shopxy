import Link from "next/link";
import type { ReactNode } from "react";
import { Divider } from "@/shared/ui/divider";
import { Banner } from "./banner";

/**
 * Layout for the auth screens. A calm centered column on the canvas — no card,
 * no elevation. The form and the footer link are separated by a hairline
 * divider, not a box (CLAUDE.md §9b).
 */
export function AuthShell({
  title,
  subtitle,
  children,
  footerPrompt,
  footerHref,
  footerCta,
  notice,
}: {
  title: string;
  subtitle: string;
  children: ReactNode;
  footerPrompt: string;
  footerHref: string;
  footerCta: string;
  notice?: string;
}) {
  return (
    <main className="mx-auto flex min-h-dvh w-full max-w-form flex-col justify-center px-lg py-massive">
      <p className="text-label-md uppercase tracking-wide text-brand">
        ShopXY
      </p>
      <h1 className="mt-xs text-headline-md text-ink">{title}</h1>
      <p className="mt-sm text-body-md text-muted">{subtitle}</p>

      {notice ? (
        <div className="mt-lg">
          <Banner variant="success" message={notice} />
        </div>
      ) : null}

      <div className="mt-xxl">{children}</div>

      <Divider className="mt-xxl" />

      <p className="mt-lg text-center text-body-md text-muted">
        {footerPrompt}{" "}
        <Link
          href={footerHref}
          className="text-brand-strong underline-offset-2 hover:underline focus-visible:underline focus-visible:outline-none"
        >
          {footerCta}
        </Link>
      </p>
    </main>
  );
}

/** Inline error banner — hairline error border, no fill, not chunky. */
export function AuthErrorBanner({ message }: { message: string }) {
  return (
    <div
      role="alert"
      className="flex items-start gap-sm rounded-md border border-error bg-error-soft px-md py-sm text-body-sm text-error"
    >
      <span aria-hidden className="mt-px font-semibold">
        !
      </span>
      <span>{message}</span>
    </div>
  );
}

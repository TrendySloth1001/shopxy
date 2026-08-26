import Image from "next/image";
import Link from "next/link";
import type { ComponentType, ReactNode } from "react";
import { getTranslations } from "next-intl/server";
import { LogIn, UserPlus } from "@/shared/icons";
import { Divider } from "@/shared/ui/divider";
import { Banner } from "./banner";

const ART = {
  src: "/auth-illustration-1.jpg",
  author: "TianaZZ",
  authorUrl: "https://pixabay.com/users/tianazz-18707913/",
};

export async function AuthShell({
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
  const t = await getTranslations("auth");
  const art = ART;

  return (
    <div className="relative flex min-h-dvh flex-col">
      <AuthHeader href={footerHref} cta={footerCta} />

      <div className="grid flex-1 grid-cols-1 lg:grid-cols-2">
        <section className="relative hidden flex-col justify-center overflow-hidden px-huge py-massive lg:flex xl:px-massive">
          <Image
            src={art.src}
            alt=""
            fill
            priority
            sizes="(min-width: 1024px) 50vw, 0px"
            className="object-cover object-center"
          />
          <div
            aria-hidden
            className="absolute inset-0 bg-linear-to-r from-canvas/10 via-canvas/40 to-canvas"
          />

          <p className="absolute inset-x-huge bottom-massive text-body-sm text-subtle xl:inset-x-massive">
            {t.rich("shell.attribution", {
              author: () => (
                <a
                  href={art.authorUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="underline underline-offset-2 hover:text-ink"
                >
                  {art.author}
                </a>
              ),
              pixabay: (chunks) => (
                <a
                  href="https://pixabay.com"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="underline underline-offset-2 hover:text-ink"
                >
                  {chunks}
                </a>
              ),
            })}
          </p>
        </section>

        <main className="relative flex flex-col justify-center px-lg py-massive">
          <div aria-hidden className="fixed inset-0 z-0 lg:hidden">
            <Image
              src="/auth-boho.jpg"
              alt=""
              fill
              priority
              sizes="100vw"
              className="object-cover object-top"
            />
            <div className="absolute inset-0 bg-linear-to-b from-canvas/65 via-canvas/80 to-canvas/95 backdrop-blur-xl" />
          </div>

          <div className="relative z-10 mx-auto w-full max-w-auth">
            <h1 className="font-display text-headline-md text-ink">{title}</h1>
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
          </div>
        </main>
      </div>
    </div>
  );
}

async function AuthHeader({ href, cta }: { href: string; cta: string }) {
  return (
    <header className="absolute inset-x-0 top-0 z-20">
      <div className="flex h-16 w-full items-center justify-between px-lg sm:px-xl">
        <Link
          href="/login"
          className="flex items-center gap-sm focus-visible:outline-none focus-visible:underline"
        >
          <Image
            src="/shopxy-icon.png"
            alt="ShopXY"
            width={34}
            height={34}
            priority
          />
          <span className="font-display text-label-lg text-ink">
            ShopXY <span className="hidden text-subtle sm:inline">· Merchant</span>
          </span>
        </Link>
        <nav className="flex items-center gap-sm">
          <HeaderChip href={href} icon={href === "/login" ? LogIn : UserPlus}>
            {cta}
          </HeaderChip>
        </nav>
      </div>
    </header>
  );
}

function HeaderChip({
  href,
  icon: Icon,
  children,
}: {
  href: string;
  icon: ComponentType<{ size?: number }>;
  children: ReactNode;
}) {
  return (
    <Link
      href={href}
      className="inline-flex h-9 items-center gap-xs rounded-full border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
    >
      <Icon size={16} />
      {children}
    </Link>
  );
}

export function AuthErrorBanner({ message }: { message: string }) {
  return (
    <div
      role="alert"
      className="flex items-start gap-sm rounded-xl border border-error bg-error-soft px-md py-sm text-body-sm text-error"
    >
      <span aria-hidden className="mt-px font-semibold">
        !
      </span>
      <span>{message}</span>
    </div>
  );
}

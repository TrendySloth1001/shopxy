import Image from "next/image";
import Link from "next/link";
import type { ComponentType, ReactNode } from "react";
import { LogIn, UserPlus } from "lucide-react";
import { Divider } from "@/shared/ui/divider";
import { Banner } from "./banner";

/** Boho line-art background for the showcase panel (royalty-free, Pixabay).
 *  Credited at the foot of the panel. */
const ART = {
  src: "/auth-illustration-1.jpg",
  author: "TianaZZ",
  authorUrl: "https://pixabay.com/users/tianazz-18707913/",
};

/**
 * Layout for the auth screens. A slim brand header on top, then two columns on
 * large screens: a boho illustration on the left that fades (via a gradient
 * shade) into the canvas so it merges seamlessly into the form column on the
 * right. On phones the illustration is hidden and the form takes over.
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
  const art = ART;

  return (
    <div className="relative flex min-h-dvh flex-col">
      <AuthHeader />

      <div className="grid flex-1 grid-cols-1 lg:grid-cols-2">
        {/* Illustration panel — large screens only. Runs full height *behind*
            the transparent nav so the bar reads as see-through. */}
        <section className="relative hidden flex-col justify-center overflow-hidden px-huge py-massive lg:flex xl:px-massive">
          <Image
            src={art.src}
            alt=""
            fill
            priority
            sizes="(min-width: 1024px) 50vw, 0px"
            className="object-cover object-center"
          />
          {/* Gradient shade — dense artwork on the left, fading to solid canvas
              on the right so the panel merges into the form column. */}
          <div
            aria-hidden
            className="absolute inset-0 bg-linear-to-r from-canvas/10 via-canvas/40 to-canvas"
          />

          {/* Attribution for the royalty-free artwork (Pixabay). */}
          <p className="absolute inset-x-huge bottom-massive text-body-sm text-subtle xl:inset-x-massive">
            Illustration by{" "}
            <a
              href={art.authorUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="underline underline-offset-2 hover:text-ink"
            >
              {art.author}
            </a>{" "}
            on{" "}
            <a
              href="https://pixabay.com"
              target="_blank"
              rel="noopener noreferrer"
              className="underline underline-offset-2 hover:text-ink"
            >
              Pixabay
            </a>
          </p>
        </section>

        {/* Focused form column — vertically centred in its half. */}
        <main className="relative flex flex-col justify-center px-lg py-massive">
          {/* Mobile-only boho backdrop — the large-screen illustration panel is
              hidden below lg, so the art sits behind the form instead. `fixed`
              pins it to the viewport so it stays put (and doesn't resize) when
              the on-screen keyboard opens. A translucent, frosted canvas wash
              (theme-aware) lets the art read through while keeping the form
              legible. */}
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

/**
 * Top bar for the auth screens — the signed-OUT counterpart to AppHeader. Brand
 * lockup (the shared ShopXY storefront mark) on the left; sign-in / create-
 * account chips on the right. It deliberately does NOT use `useAuth`, so it can
 * render before there's a session.
 */
function AuthHeader() {
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
          <HeaderChip href="/login" icon={LogIn}>
            Sign in
          </HeaderChip>
          <HeaderChip href="/register" icon={UserPlus} variant="ink">
            Create account
          </HeaderChip>
        </nav>
      </div>
    </header>
  );
}

/** Icon + label pill used in the auth header. Sizes to its content (CLAUDE.md). */
function HeaderChip({
  href,
  icon: Icon,
  children,
  variant = "default",
}: {
  href: string;
  icon: ComponentType<{ size?: number }>;
  children: ReactNode;
  variant?: "default" | "ink";
}) {
  const styles =
    variant === "ink"
      ? "border-ink bg-inverse-surface text-on-inverse hover:bg-ink/90"
      : "border-hairline text-ink hover:bg-surface-tint";
  return (
    <Link
      href={href}
      className={`inline-flex h-9 items-center gap-xs rounded-full border px-md text-label-md transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft ${styles}`}
    >
      <Icon size={16} />
      {children}
    </Link>
  );
}

/** Inline error banner — hairline error border, no fill, not chunky. */
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

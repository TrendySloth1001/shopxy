"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { useAuth } from "../auth-context";
import { Avatar } from "./avatar";

export function AppHeader() {
  const { user, logout } = useAuth();
  const router = useRouter();
  const pathname = usePathname();
  const t = useTranslations("auth");

  async function onSignOut() {
    await logout();
    router.replace("/login");
  }

  return (
    <header className="border-b border-hairline bg-canvas">
      <div className="mx-auto flex h-14 max-w-content items-center justify-between px-lg">
        <Link href="/dashboard" className="text-label-lg text-ink">
          ShopXY <span className="text-subtle">· Merchant</span>
        </Link>
        <nav className="flex items-center gap-lg">
          <HeaderLink href="/dashboard" active={pathname === "/dashboard"}>
            {t("appHeader.dashboard")}
          </HeaderLink>
          <HeaderLink href="/account" active={pathname === "/account"}>
            {t("appHeader.account")}
          </HeaderLink>
          <Link
            href="/account"
            aria-label={t("appHeader.account")}
            className="rounded-full focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            <Avatar url={user?.avatarUrl} name={user?.name ?? ""} size={28} />
          </Link>
          <button
            type="button"
            onClick={onSignOut}
            className="text-label-md text-muted transition-colors hover:text-ink focus-visible:text-ink focus-visible:outline-none"
          >
            {t("appHeader.signOut")}
          </button>
        </nav>
      </div>
    </header>
  );
}

function HeaderLink({
  href,
  active,
  children,
}: {
  href: string;
  active: boolean;
  children: React.ReactNode;
}) {
  return (
    <Link
      href={href}
      aria-current={active ? "page" : undefined}
      className={`text-label-md transition-colors hover:text-ink focus-visible:outline-none ${
        active ? "text-ink" : "text-muted"
      }`}
    >
      {children}
    </Link>
  );
}

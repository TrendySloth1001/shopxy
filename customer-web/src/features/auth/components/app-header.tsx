"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useAuth } from "../auth-context";
import { Avatar } from "./avatar";

/** Top bar for signed-in pages. Hairline underline, no elevation. */
export function AppHeader() {
  const { user, logout } = useAuth();
  const router = useRouter();
  const pathname = usePathname();

  async function onSignOut() {
    await logout();
    router.replace("/login");
  }

  return (
    <header className="border-b border-hairline bg-canvas">
      <div className="mx-auto flex h-14 max-w-content items-center justify-between px-lg">
        <Link href="/dashboard" className="text-label-lg text-ink">
          ShopXY
        </Link>
        <nav className="flex items-center gap-lg">
          <HeaderLink href="/dashboard" active={pathname === "/dashboard"}>
            Home
          </HeaderLink>
          <HeaderLink href="/account" active={pathname === "/account"}>
            Account
          </HeaderLink>
          <Link
            href="/account"
            aria-label="Account"
            className="rounded-full focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            <Avatar url={user?.avatarUrl} name={user?.name ?? ""} size={28} />
          </Link>
          <button
            type="button"
            onClick={onSignOut}
            className="text-label-md text-muted transition-colors hover:text-ink focus-visible:text-ink focus-visible:outline-none"
          >
            Sign out
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

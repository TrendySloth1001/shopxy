"use client";

import type { ReactNode } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  BookOpen,
  ChevronRight,
  FileText,
  Gift,
  Heart,
  History,
  Lock,
  LogOut,
  MapPin,
  MessageSquare,
  Package,
  Pencil,
  Receipt,
  RotateCcw,
  ShieldCheck,
  Store,
  Ticket,
  User,
} from "@/shared/icons";
import { RequireAuth } from "@/features/auth/components/require-auth";
import { AppHeader } from "@/features/auth/components/app-header";
import { Avatar } from "@/features/auth/components/avatar";
import { useAuth } from "@/features/auth/auth-context";
import { Divider } from "@/shared/ui/divider";
import { BackButton } from "@/shared/ui/back-button";
import { DeveloperEnvironmentSection } from "@/features/settings/environment-picker";

/** A single destination in the account hub. */
interface HubLink {
  href: string;
  icon: ReactNode;
  label: string;
  description: string;
}

const HUB_GROUPS: { heading: string; links: HubLink[] }[] = [
  {
    heading: "Shopping",
    links: [
      {
        href: "/orders",
        icon: <Package size={18} />,
        label: "Orders",
        description: "Track and manage your orders",
      },
      {
        href: "/orders/pending-payments",
        icon: <Receipt size={18} />,
        label: "Pending payments",
        description: "Pay for orders awaiting payment",
      },
      {
        href: "/returns",
        icon: <RotateCcw size={18} />,
        label: "Returns",
        description: "View and raise return requests",
      },
      {
        href: "/wishlist",
        icon: <Heart size={18} />,
        label: "Wishlist",
        description: "Products you have saved",
      },
      {
        href: "/cart",
        icon: <Gift size={18} />,
        label: "Cart",
        description: "Items in your shopping cart",
      },
    ],
  },
  {
    heading: "Account",
    links: [
      {
        href: "/account/addresses",
        icon: <MapPin size={18} />,
        label: "Addresses",
        description: "Delivery addresses",
      },
      {
        href: "/account/coupons",
        icon: <Ticket size={18} />,
        label: "Coupons",
        description: "Discount codes and offers",
      },
      {
        href: "/account/reviews",
        icon: <MessageSquare size={18} />,
        label: "Reviews",
        description: "Reviews you have written",
      },
      {
        href: "/account/recently-viewed",
        icon: <History size={18} />,
        label: "Recently viewed",
        description: "Products you browsed",
      },
    ],
  },
  {
    heading: "Settings",
    links: [
      {
        href: "/account/profile",
        icon: <User size={18} />,
        label: "Profile",
        description: "Photo, name and contact details",
      },
      {
        href: "/account/security",
        icon: <Lock size={18} />,
        label: "Login & security",
        description: "Password and active sessions",
      },
      {
        href: "/account/privacy",
        icon: <ShieldCheck size={18} />,
        label: "Data & privacy",
        description: "Export or delete your data",
      },
    ],
  },
  {
    heading: "B2B",
    links: [
      {
        href: "/merchants",
        icon: <Store size={18} />,
        label: "My merchants",
        description: "Shops you are linked to",
      },
      {
        href: "/invitations",
        icon: <BookOpen size={18} />,
        label: "Invitations",
        description: "Pending and past invitations",
      },
      {
        href: "/merchants",
        icon: <FileText size={18} />,
        label: "Invoice ledgers",
        description: "Invoices from linked shops",
      },
    ],
  },
];

export default function AccountPage() {
  return (
    <RequireAuth>
      <AppHeader />
      <main className="mx-auto max-w-shell px-lg pb-massive pt-xl">
        <BackButton fallback="/" className="mb-md" />
        <AccountIdentity />
        <AccountHub />
        {/* Renders nothing unless this is the developer account. */}
        <DeveloperEnvironmentSection />
      </main>
    </RequireAuth>
  );
}

/** "Jun 2024" from an ISO timestamp, or null if absent / unparseable. */
function formatMemberSince(createdAt?: string): string | null {
  if (!createdAt) return null;
  const date = new Date(createdAt);
  if (Number.isNaN(date.getTime())) return null;
  return new Intl.DateTimeFormat("en-IN", {
    month: "short",
    year: "numeric",
  }).format(date);
}

/**
 * Identity band — the page's anchor. Shows who you're signed in as plus the
 * two highest-value account actions (edit profile, sign out). Built from
 * whitespace + a single hairline, not a chunky card (CLAUDE.md §9b).
 */
function AccountIdentity() {
  const { user, logout } = useAuth();
  const router = useRouter();
  const memberSince = formatMemberSince(user?.createdAt);

  async function onSignOut() {
    await logout();
    router.replace("/login");
  }

  return (
    <header className="flex flex-col gap-lg sm:flex-row sm:items-center sm:justify-between">
      <div className="flex items-center gap-lg">
        <Avatar url={user?.avatarUrl} name={user?.name ?? ""} size={64} />
        <div className="min-w-0">
          <h1 className="truncate text-headline-sm text-ink">
            {user?.name?.trim() || "Your account"}
          </h1>
          {user?.email ? (
            <p className="truncate text-body-md text-muted">{user.email}</p>
          ) : null}
          <div className="mt-xs flex flex-wrap items-center gap-x-sm gap-y-xs text-body-sm text-subtle">
            <span className="inline-flex items-center gap-xs rounded-full bg-brand-soft px-sm py-xxs text-label-md text-brand-strong">
              Customer
            </span>
            {memberSince ? <span>Member since {memberSince}</span> : null}
          </div>
        </div>
      </div>

      <div className="flex flex-wrap items-center gap-sm">
        <Link
          href="/account/profile"
          className="inline-flex h-10 items-center justify-center gap-xs rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
        >
          <Pencil size={16} aria-hidden />
          Edit profile
        </Link>
        <button
          type="button"
          onClick={onSignOut}
          className="inline-flex h-10 items-center justify-center gap-xs rounded-button px-md text-label-md text-muted transition-colors hover:text-ink focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
        >
          <LogOut size={16} aria-hidden />
          Sign out
        </button>
      </div>
    </header>
  );
}

/**
 * Quick-access hub — every account destination, grouped and described so users
 * can scan rather than hunt (Baymard: don't truncate the account menu; group
 * with secondary text). Rendered as a responsive tile grid.
 */
function AccountHub() {
  return (
    <section className="mt-xxl">
      <Divider className="mb-xxl" />
      <div className="flex flex-col gap-xxl">
        {HUB_GROUPS.map((group) => (
          <div key={group.heading}>
            <h2 className="mb-md text-label-md uppercase tracking-wide text-brand">
              {group.heading}
            </h2>
            <ul className="grid grid-cols-1 gap-md sm:grid-cols-2 lg:grid-cols-3">
              {group.links.map((link) => (
                <li key={link.href + link.label}>
                  <Link
                    href={link.href}
                    className="group flex h-full items-center gap-md rounded-md border border-hairline bg-white px-md py-md transition-colors hover:border-brand-soft hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-brand-soft"
                  >
                    <span className="flex size-10 shrink-0 items-center justify-center rounded-lg bg-canvas text-muted transition-colors group-hover:bg-brand-soft group-hover:text-brand-strong">
                      {link.icon}
                    </span>
                    <span className="min-w-0 flex-1">
                      <span className="block text-body-md font-semibold text-ink">
                        {link.label}
                      </span>
                      <span className="block truncate text-body-sm text-muted">
                        {link.description}
                      </span>
                    </span>
                    <ChevronRight
                      size={16}
                      aria-hidden
                      className="shrink-0 text-disabled transition-transform group-hover:translate-x-xxs group-hover:text-muted"
                    />
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        ))}
      </div>
    </section>
  );
}

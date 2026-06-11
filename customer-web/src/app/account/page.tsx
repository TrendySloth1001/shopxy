"use client";

import type { ReactNode } from "react";
import Link from "next/link";
import {
  BookOpen,
  ChevronRight,
  FileText,
  Gift,
  Heart,
  History,
  MapPin,
  MessageSquare,
  Package,
  Receipt,
  RotateCcw,
  Store,
  Ticket,
  Wallet,
} from "lucide-react";
import { RequireAuth } from "@/features/auth/components/require-auth";
import { AppHeader } from "@/features/auth/components/app-header";
import { ProfileForm } from "@/features/auth/components/profile-form";
import { SecuritySection } from "@/features/auth/components/security-section";
import { DangerZone } from "@/features/auth/components/danger-zone";
import { Divider } from "@/shared/ui/divider";
import { BackButton } from "@/shared/ui/back-button";

/** Hub link descriptor. */
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
        href: "/account/wallet",
        icon: <Wallet size={18} />,
        label: "Wallet",
        description: "Balance and transaction history",
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
      <main className="mx-auto max-w-content px-lg py-xxxl">
        <BackButton fallback="/" className="mb-sm" />
        <h1 className="text-headline-md text-ink">Account</h1>
        <p className="mt-sm text-body-md text-muted">
          Manage your profile, security and data.
        </p>

        <section className="py-xxl">
          <Divider className="mb-xxl" />
          <div className="grid gap-xl md:grid-cols-[200px_1fr]">
            <div>
              <h2 className="text-title-md text-ink">Quick links</h2>
              <p className="mt-xs text-body-sm text-muted">Your activity at a glance.</p>
            </div>
            <div className="flex flex-col gap-xxl">
              {HUB_GROUPS.map((group) => (
                <div key={group.heading}>
                  <p className="mb-sm text-label-md uppercase tracking-wide text-brand">
                    {group.heading}
                  </p>
                  <ul className="divide-y divide-hairline rounded-md border border-hairline bg-white">
                    {group.links.map((link) => (
                      <li key={link.href + link.label}>
                        <Link
                          href={link.href}
                          className="flex items-center gap-md px-md py-sm transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-brand-soft"
                        >
                          <span className="flex size-9 shrink-0 items-center justify-center rounded-lg bg-canvas text-muted">
                            {link.icon}
                          </span>
                          <span className="min-w-0 flex-1">
                            <span className="block text-body-md font-semibold text-ink">
                              {link.label}
                            </span>
                            <span className="block text-body-sm text-muted">
                              {link.description}
                            </span>
                          </span>
                          <ChevronRight size={16} className="shrink-0 text-disabled" aria-hidden />
                        </Link>
                      </li>
                    ))}
                  </ul>
                </div>
              ))}
            </div>
          </div>
        </section>

        <Section title="Profile" description="Your name and contact details.">
          <ProfileForm />
        </Section>

        <Section title="Security" description="Your password and active sessions.">
          <SecuritySection />
        </Section>

        <Section
          title="Data & privacy"
          description="Export a copy of your data, or delete your account."
        >
          <DangerZone />
        </Section>
      </main>
    </RequireAuth>
  );
}

/** Label rail + content, separated from the previous section by a divider. */
function Section({
  title,
  description,
  children,
}: {
  title: string;
  description: string;
  children: ReactNode;
}) {
  return (
    <section className="py-xxl">
      <Divider className="mb-xxl" />
      <div className="grid gap-xl md:grid-cols-[200px_1fr]">
        <div>
          <h2 className="text-title-md text-ink">{title}</h2>
          <p className="mt-xs text-body-sm text-muted">{description}</p>
        </div>
        <div className="max-w-form">{children}</div>
      </div>
    </section>
  );
}

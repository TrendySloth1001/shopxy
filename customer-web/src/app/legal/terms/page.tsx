import type { Metadata } from "next";
import { LegalDoc, LegalSection } from "@/features/legal/legal-doc";
import { GrievanceOfficerSection } from "@/features/legal/grievance-officer";

export const metadata: Metadata = { title: "Terms of Service · ShopXY" };

export default function TermsPage() {
  return (
    <LegalDoc title="Terms of Service" updated="June 2026">
      <LegalSection heading="Acceptance">
        <p>
          By creating a ShopXY account and placing orders, you agree to these terms. You confirm
          you are at least 18 years old and shopping for your own personal use.
        </p>
      </LegalSection>

      <LegalSection heading="The marketplace">
        <p>
          ShopXY is a marketplace. Orders are accepted and fulfilled by individual shops, not by
          ShopXY. Each shop is responsible for its own pricing, availability, product
          descriptions, and fulfilment. The displayed price is inclusive of all taxes unless the
          shop states otherwise.
        </p>
      </LegalSection>

      <LegalSection heading="Your account">
        <p>
          Keep your login secure and your details accurate. You&apos;re responsible for activity
          under your account. Notify us at support@shopxy.app if you suspect unauthorised access.
        </p>
      </LegalSection>

      <LegalSection heading="Acceptable use">
        <p>
          Don&apos;t misuse the order, cancel, return, payment or messaging systems, attempt to
          defraud a shop, or use ShopXY for any unlawful purpose. We may suspend accounts that
          violate these terms.
        </p>
      </LegalSection>

      <LegalSection heading="Orders, cancellations &amp; returns">
        <p>
          Cancellation, return, refund and shipping terms are set out in our{" "}
          <a className="text-ink underline" href="/legal/policies">
            consumer policies
          </a>
          . Each shop may set additional, stricter rules within those limits, shown to you before
          you confirm an order.
        </p>
      </LegalSection>

      <LegalSection heading="Payments">
        <p>
          Online payments and refunds are processed by our payment partner, Razorpay, under their
          terms. Cash-on-delivery is settled directly with the shop on delivery.
        </p>
      </LegalSection>

      <LegalSection heading="Availability &amp; liability">
        <p>
          ShopXY is provided &ldquo;as is&rdquo;. To the extent permitted by law, we aren&apos;t
          liable for indirect or consequential losses. We aim for high availability but don&apos;t
          guarantee uninterrupted service.
        </p>
      </LegalSection>

      <LegalSection heading="Governing law">
        <p>These terms are governed by the laws of India. Questions? Email support@shopxy.app.</p>
      </LegalSection>

      <GrievanceOfficerSection />
    </LegalDoc>
  );
}

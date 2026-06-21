import type { Metadata } from "next";
import { LegalDoc, LegalSection } from "@/features/legal/legal-doc";
import { GrievanceOfficerSection } from "@/features/legal/grievance-officer";

export const metadata: Metadata = { title: "Consumer Policies · ShopXY" };

export default function PoliciesPage() {
  return (
    <LegalDoc title="Consumer Policies" updated="June 2026">
      <LegalSection heading="Overview">
        <p>
          ShopXY is a marketplace; each order is fulfilled by an individual shop. The policies
          below set the baseline that applies across ShopXY. A shop may offer terms that are more
          generous, or set stricter rules within these limits — those are shown to you before you
          confirm an order.
        </p>
      </LegalSection>

      <LegalSection heading="Cancellation">
        <p>
          You can cancel an order — or a per-shop part of it — free of charge from the order
          detail page any time before the shop marks it as shipped or out for delivery. Once an
          order has shipped, it can no longer be cancelled, but it may be eligible for return
          after delivery. If you paid online, any amount already charged for a cancelled order is
          refunded in full.
        </p>
      </LegalSection>

      <LegalSection heading="Returns">
        <p>
          Eligible items can be returned within <span className="text-ink">7 days</span> of
          delivery. An item must be unused, in its original condition and packaging, with tags and
          invoice intact. Certain items are not returnable for hygiene, safety or perishability
          reasons (for example: food, personal-care items once opened, and made-to-order goods);
          where an item is non-returnable, that is shown on the product page. Raise a return from
          the order detail page; the shop reviews and approves eligible requests.
        </p>
      </LegalSection>

      <LegalSection heading="Refunds">
        <p>
          Once a return is received and approved, or an order is cancelled, your refund is
          initiated within <span className="text-ink">2 business days</span>. Refunds to an
          online payment method (UPI, card, netbanking) are processed via Razorpay and typically
          reach your account within <span className="text-ink">5–7 business days</span>, depending
          on your bank. For cash-on-delivery orders, refunds are credited to your ShopXY wallet or
          to a bank account you provide. You are refunded the full amount you paid for the returned
          items, including taxes.
        </p>
      </LegalSection>

      <LegalSection heading="Shipping &amp; delivery">
        <p>
          Delivery is handled by the shop you order from. Estimated delivery is typically 3–5 days
          for standard delivery; the exact window and any delivery charge are shown at checkout
          before you pay, and the shop confirms a final date. If an item can&apos;t be delivered to
          your address, we&apos;ll let you know and cancel that part of the order with a full
          refund.
        </p>
      </LegalSection>

      <GrievanceOfficerSection />
    </LegalDoc>
  );
}

import type { Metadata } from "next";
import { LegalDoc, LegalSection } from "@/features/legal/legal-doc";

export const metadata: Metadata = { title: "Terms of Service · ShopXY" };

export default function TermsPage() {
  return (
    <LegalDoc title="Terms of Service" updated="June 2026">
      <LegalSection heading="Acceptance">
        <p>
          By creating a ShopXY account you agree to these terms. If you use ShopXY on behalf of a
          business, you confirm you’re authorised to bind that business.
        </p>
      </LegalSection>
      <LegalSection heading="Your account">
        <p>
          Keep your login secure and your shop details accurate. You’re responsible for activity
          under your account and for any team members you invite.
        </p>
      </LegalSection>
      <LegalSection heading="Acceptable use">
        <p>
          Don’t use ShopXY for unlawful goods or activity, to infringe others’ rights, or to disrupt
          the service. You’re responsible for the legality of your listings, invoices and tax
          handling.
        </p>
      </LegalSection>
      <LegalSection heading="Your content & records">
        <p>
          You own the business data you put into ShopXY. You grant us the limited rights needed to
          host and process it to run the service. You’re responsible for keeping your own backups of
          critical records.
        </p>
      </LegalSection>
      <LegalSection heading="Payments & payouts">
        <p>
          Where you enable payouts, settlement and KYC are handled by our payment partner under their
          terms. Taxes (e.g. GST) on your sales are your responsibility.
        </p>
      </LegalSection>
      <LegalSection heading="Availability & liability">
        <p>
          ShopXY is provided “as is”. To the extent permitted by law, we aren’t liable for indirect
          or consequential losses. We aim for high availability but don’t guarantee uninterrupted
          service.
        </p>
      </LegalSection>
      <LegalSection heading="Termination">
        <p>
          You can stop using ShopXY at any time and delete your account from Settings. We may suspend
          accounts that violate these terms.
        </p>
      </LegalSection>
      <LegalSection heading="Governing law">
        <p>These terms are governed by the laws of India. Questions? Email support@shopxy.app.</p>
      </LegalSection>
    </LegalDoc>
  );
}

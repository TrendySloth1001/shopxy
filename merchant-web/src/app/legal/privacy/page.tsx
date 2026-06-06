import type { Metadata } from "next";
import { LegalDoc, LegalSection } from "@/features/legal/legal-doc";

export const metadata: Metadata = { title: "Privacy Policy · ShopXY" };

export default function PrivacyPage() {
  return (
    <LegalDoc title="Privacy Policy" updated="June 2026">
      <LegalSection heading="Overview">
        <p>
          ShopXY (“we”, “us”) helps merchants run their shop — inventory, invoices, parties and
          payments. This policy explains what personal data we collect, why, and your rights under
          India’s Digital Personal Data Protection Act, 2023 (DPDP).
        </p>
      </LegalSection>
      <LegalSection heading="What we collect">
        <p>
          Account details (name, email, phone), shop details (name, address, GSTIN/PAN where you
          provide them), and the business records you create in the app (products, invoices,
          customers, vendors, payments). We also log basic technical data to keep the service
          secure and working.
        </p>
      </LegalSection>
      <LegalSection heading="How we use it">
        <p>
          To provide the service, generate your invoices and reports, send transactional emails you
          opt into, and meet legal/tax obligations. We do not sell your personal data.
        </p>
      </LegalSection>
      <LegalSection heading="Sharing">
        <p>
          We share data only with processors who help us run ShopXY (e.g. payment and infrastructure
          providers such as Razorpay for payouts), and where required by law. Payment KYC details you
          submit for payouts are forwarded to the payment provider and not stored by us.
        </p>
      </LegalSection>
      <LegalSection heading="Retention & security">
        <p>
          Financial records (e.g. invoices) are retained for the period Indian law requires. We
          protect data with encryption in transit and access controls. No system is perfectly secure,
          so we encourage strong passwords and care with account access.
        </p>
      </LegalSection>
      <LegalSection heading="Your rights">
        <p>
          You can access, correct, export or delete your personal data from Settings → Data &amp;
          privacy, subject to records we must legally retain. Contact us for any request.
        </p>
      </LegalSection>
      <LegalSection heading="Contact">
        <p>For privacy questions, email privacy@shopxy.app.</p>
      </LegalSection>
    </LegalDoc>
  );
}

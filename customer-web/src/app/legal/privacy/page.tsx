import type { Metadata } from "next";
import { LegalDoc, LegalSection } from "@/features/legal/legal-doc";
import { GrievanceOfficerSection } from "@/features/legal/grievance-officer";

export const metadata: Metadata = { title: "Privacy Policy · ShopXY" };

export default function PrivacyPage() {
  return (
    <LegalDoc title="Privacy Policy" updated="June 2026">
      <LegalSection heading="Overview">
        <p>
          ShopXY (&ldquo;we&rdquo;, &ldquo;us&rdquo;) is a marketplace that connects you to
          shops near you — you browse what they stock, place orders, pay, and keep every
          invoice in one place. This policy explains what personal data we collect, why, how
          long we keep it, and your rights under India&apos;s Digital Personal Data Protection
          Act, 2023 (DPDP).
        </p>
      </LegalSection>

      <LegalSection heading="What we collect">
        <p>
          Account details (name, email, phone), delivery addresses you add, your orders,
          returns, payments, wallet activity, reviews, and the messages you exchange with a
          shop. We also log basic technical data (device, app version, IP, error logs) to keep
          the service secure and working.
        </p>
      </LegalSection>

      <LegalSection heading="How we use it">
        <p>
          To route and fulfil your orders, generate invoices, process payments and refunds,
          provide support, prevent fraud, and meet legal and tax obligations. We do not sell
          your personal data, and we do not use it for targeted advertising to children.
        </p>
      </LegalSection>

      <LegalSection heading="Who we share it with">
        <p>
          The shop you order from sees that order and the name, phone and delivery address
          snapshotted onto it. Beyond that, we share data only with the processors who help us
          run ShopXY:
        </p>
        <ul className="flex flex-col gap-xs">
          <li>
            <span className="text-ink">Razorpay Software Private Limited</span> — payment
            collection, refunds and payouts. Payment and KYC details you submit are handled by
            Razorpay under their terms and are not stored by us.
          </li>
          <li>
            <span className="text-ink">Cloud hosting and infrastructure provider</span> —
            application hosting, database, object storage and backups. [TO FILL: name the
            hosting provider, e.g. AWS Mumbai / specific vendor]
          </li>
        </ul>
        <p>
          We also disclose data where required by law or to enforce our terms. We do not sell
          your personal data.
        </p>
      </LegalSection>

      <LegalSection heading="Retention schedule">
        <p>We keep data only as long as we need it:</p>
        <ul className="flex flex-col gap-xs">
          <li>
            <span className="text-ink">Invoices, orders and payment records</span> — retained
            for 8 years, the period required under Indian tax and company law.
          </li>
          <li>
            <span className="text-ink">Account profile and addresses</span> — kept while your
            account is active; deleted (or anonymised) within 90 days of account deletion,
            except records we must legally retain.
          </li>
          <li>
            <span className="text-ink">Support tickets and grievance records</span> — up to 3
            years from resolution.
          </li>
          <li>
            <span className="text-ink">Technical and security logs</span> — up to 180 days.
          </li>
        </ul>
      </LegalSection>

      <LegalSection heading="Your rights under the DPDP Act">
        <p>
          You can access, correct, update, export or delete your personal data from Account →
          Data &amp; privacy in the app, subject to records we must legally retain. You may also
          withdraw consent and nominate another person to exercise your rights in the event of
          death or incapacity. Export and deletion requests are honoured by our systems; contact
          our Grievance Officer for anything you can&apos;t do in-app.
        </p>
      </LegalSection>

      <LegalSection heading="Children's data">
        <p>
          ShopXY is intended for users aged 18 and over. We do not knowingly process the
          personal data of a child (a person under 18) without verifiable consent from a parent
          or lawful guardian, and we do not undertake tracking, behavioural monitoring, or
          targeted advertising directed at children. If we learn that we hold a child&apos;s data
          without the required consent, we will delete it.
        </p>
      </LegalSection>

      <LegalSection heading="Cross-border transfers">
        <p>
          Your personal data is primarily stored and processed on infrastructure located in
          India. Where a processor (such as a payment provider) operates outside India, any
          transfer is limited to that purpose and is made only to countries not restricted by
          the Government of India under the DPDP Act, with contractual safeguards in place.
        </p>
      </LegalSection>

      <LegalSection heading="Security &amp; breach notification">
        <p>
          We protect data with encryption in transit, access controls, and least-privilege
          handling of payment data (forwarded to our payment provider, not stored by us). No
          system is perfectly secure. In the event of a personal-data breach, we will notify the
          Data Protection Board of India and affected users without undue delay and within the
          timelines prescribed under the DPDP Act and its rules. We encourage strong passwords
          and care with account access.
        </p>
      </LegalSection>

      <GrievanceOfficerSection />

      <LegalSection heading="Contact">
        <p>For privacy questions, email privacy@shopxy.app.</p>
      </LegalSection>
    </LegalDoc>
  );
}

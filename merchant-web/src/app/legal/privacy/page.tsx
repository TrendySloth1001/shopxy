import type { Metadata } from "next";
import { LegalDoc, LegalSection } from "@/features/legal/legal-doc";
import { GrievanceOfficerSection } from "@/features/legal/grievance-officer";

export const metadata: Metadata = { title: "Privacy Policy · ShopXY" };

export default function PrivacyPage() {
  return (
    <LegalDoc title="Privacy Policy" updated="June 2026">
      <LegalSection heading="Overview">
        <p>
          ShopXY (“we”, “us”) helps merchants run their shop — inventory, invoices, parties and
          payments. This policy explains what personal data we collect, why, how long we keep it,
          and your rights under India’s Digital Personal Data Protection Act, 2023 (DPDP).
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
          opt into, and meet legal/tax obligations. We do not sell your personal data, and we do not
          use it for targeted advertising to children.
        </p>
      </LegalSection>

      <LegalSection heading="Who we share it with">
        <p>
          We share data only with the processors who help us run ShopXY:
        </p>
        <ul className="flex flex-col gap-xs">
          <li>
            <span className="text-ink">Razorpay Software Private Limited</span> — payment
            collection, refunds and payouts. Payment KYC details you submit for payouts are
            forwarded to Razorpay under their terms and are not stored by us.
          </li>
          <li>
            <span className="text-ink">Cloud hosting and infrastructure provider</span> —
            application hosting, database, object storage and backups. [TO FILL: name the hosting
            provider, e.g. AWS Mumbai / specific vendor]
          </li>
        </ul>
        <p>
          We also disclose data where required by law. We do not sell your personal data.
        </p>
      </LegalSection>

      <LegalSection heading="Retention schedule">
        <p>We keep data only as long as we need it:</p>
        <ul className="flex flex-col gap-xs">
          <li>
            <span className="text-ink">Invoices, payments and tax records</span> — retained for 8
            years, the period required under Indian tax and company law.
          </li>
          <li>
            <span className="text-ink">Account and shop profile</span> — kept while your account is
            active; deleted (or anonymised) within 90 days of account deletion, except records we
            must legally retain.
          </li>
          <li>
            <span className="text-ink">Support tickets and grievance records</span> — up to 3 years
            from resolution.
          </li>
          <li>
            <span className="text-ink">Technical and security logs</span> — up to 180 days.
          </li>
        </ul>
      </LegalSection>

      <LegalSection heading="Your rights under the DPDP Act">
        <p>
          You can access, correct, export or delete your personal data from Settings → Data &amp;
          privacy, subject to records we must legally retain. Export and deletion requests are
          honoured by our systems. You may also withdraw consent and nominate another person to
          exercise your rights in the event of death or incapacity. Contact our Grievance Officer
          for any request you can’t complete in-app.
        </p>
      </LegalSection>

      <LegalSection heading="Deleting your account and data">
        <p>
          You can permanently delete your ShopXY account and the personal data tied to it at any
          time — you do not need to contact us first:
        </p>
        <ul className="flex flex-col gap-xs">
          <li>
            <span className="text-ink">In the app</span> — go to{" "}
            <span className="text-ink">Settings → Data &amp; privacy → Delete account</span> (the
            same path on the web app, Android and iOS). You’ll confirm with your password, then the
            account and every session are erased.
          </li>
          <li>
            <span className="text-ink">By email</span> — if you can’t sign in, write to{" "}
            <a className="text-ink underline" href="mailto:privacy@shopxy.app">privacy@shopxy.app</a>{" "}
            from your registered address and we’ll verify and action the request.
          </li>
        </ul>
        <p>
          <span className="text-ink">What is deleted:</span> your profile, login credentials,
          shop settings, contacts (parties/vendors) and the business records you created, together
          with any payout draft held on your device. Deletion completes within{" "}
          <span className="text-ink">90 days</span>.
        </p>
        <p>
          <span className="text-ink">What we must keep:</span> where you have issued invoices or
          taken payments, Indian tax and company law requires us to retain those financial records
          for up to 8 years. Those records are retained in a restricted, minimised form (and
          dissociated from your login) for that period only, then deleted. A shop owner whose
          invoices are still inside that window cannot self-delete in-app — email{" "}
          <a className="text-ink underline" href="mailto:support@shopxy.app">support@shopxy.app</a>{" "}
          for a controlled wipe of everything outside the legal-retention set.
        </p>
      </LegalSection>

      <LegalSection heading="Children's data">
        <p>
          ShopXY is a business tool intended for users aged 18 and over. We do not knowingly process
          the personal data of a child (a person under 18) without verifiable consent from a parent
          or lawful guardian, and we do not undertake tracking, behavioural monitoring, or targeted
          advertising directed at children. If we learn that we hold a child’s data without the
          required consent, we will delete it.
        </p>
      </LegalSection>

      <LegalSection heading="Cross-border transfers">
        <p>
          Your personal data is primarily stored and processed on infrastructure located in India.
          Where a processor (such as a payment provider) operates outside India, any transfer is
          limited to that purpose and made only to countries not restricted by the Government of
          India under the DPDP Act, with contractual safeguards in place.
        </p>
      </LegalSection>

      <LegalSection heading="Security &amp; breach notification">
        <p>
          We protect data with encryption in transit and access controls, and we forward payment KYC
          to our payment provider rather than storing it. No system is perfectly secure. In the event
          of a personal-data breach, we will notify the Data Protection Board of India and affected
          users without undue delay and within the timelines prescribed under the DPDP Act and its
          rules. We encourage strong passwords and care with account access.
        </p>
      </LegalSection>

      <GrievanceOfficerSection />

      <LegalSection heading="Contact">
        <p>For privacy questions, email privacy@shopxy.app.</p>
      </LegalSection>
    </LegalDoc>
  );
}

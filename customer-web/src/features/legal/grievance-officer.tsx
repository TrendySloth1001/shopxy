import { LegalSection } from "@/features/legal/legal-doc";

/**
 * Grievance Officer block — mandated for Indian intermediaries (IT Rules 2021)
 * and as the contact point for consumer / DPDP grievances. Rendered on every
 * legal surface (privacy, terms, consumer policies).
 *
 * The named officer's identity, phone and postal address are pending the
 * company's final appointment — marked with [TO FILL: ...] placeholders so the
 * legal team can drop in real values before launch. The acknowledgement and
 * resolution timelines below are the committed SLAs.
 */
export function GrievanceOfficerSection() {
  return (
    <LegalSection heading="Grievance Officer">
      <p>
        In line with the Consumer Protection (E-Commerce) Rules, 2020, the
        Information Technology (Intermediary Guidelines) Rules, 2021, and India&apos;s
        Digital Personal Data Protection Act, 2023, you may contact our Grievance
        Officer with any complaint about the service or your personal data:
      </p>
      <ul className="flex flex-col gap-xs">
        <li>
          <span className="text-ink">Name:</span> [TO FILL: Grievance Officer name]
        </li>
        <li>
          <span className="text-ink">Designation:</span> [TO FILL: designation]
        </li>
        <li>
          <span className="text-ink">Email:</span> grievance@shopxy.app
        </li>
        <li>
          <span className="text-ink">Phone:</span> [TO FILL: phone number]
        </li>
        <li>
          <span className="text-ink">Postal address:</span> [TO FILL: registered
          postal address]
        </li>
      </ul>
      <p>
        We acknowledge every grievance within <span className="text-ink">48 hours</span>{" "}
        of receipt and aim to resolve consumer grievances within{" "}
        <span className="text-ink">one month</span>. Grievances relating to your
        personal data under the DPDP Act are addressed within{" "}
        <span className="text-ink">15 days</span>.
      </p>
    </LegalSection>
  );
}

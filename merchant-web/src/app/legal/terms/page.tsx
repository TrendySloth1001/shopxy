import type { Metadata } from "next";
import { getTranslations } from "next-intl/server";
import { LegalDoc, LegalSection } from "@/features/legal/legal-doc";
import { GrievanceOfficerSection } from "@/features/legal/grievance-officer";

export const metadata: Metadata = { title: "Terms of Service · ShopXY" };

export default async function TermsPage() {
  const t = await getTranslations("legal");
  return (
    <LegalDoc title={t("terms.title")} updated={t("terms.updated")}>
      <LegalSection heading={t("terms.acceptance.heading")}>
        <p>{t("terms.acceptance.body")}</p>
      </LegalSection>
      <LegalSection heading={t("terms.account.heading")}>
        <p>{t("terms.account.body")}</p>
      </LegalSection>
      <LegalSection heading={t("terms.acceptableUse.heading")}>
        <p>{t("terms.acceptableUse.body")}</p>
      </LegalSection>
      <LegalSection heading={t("terms.content.heading")}>
        <p>{t("terms.content.body")}</p>
      </LegalSection>
      <LegalSection heading={t("terms.payments.heading")}>
        <p>{t("terms.payments.body")}</p>
      </LegalSection>
      <LegalSection heading={t("terms.availability.heading")}>
        <p>{t("terms.availability.body")}</p>
      </LegalSection>
      <LegalSection heading={t("terms.termination.heading")}>
        <p>{t("terms.termination.body")}</p>
      </LegalSection>
      <LegalSection heading={t("terms.governingLaw.heading")}>
        <p>{t("terms.governingLaw.body")}</p>
      </LegalSection>
      <GrievanceOfficerSection />
    </LegalDoc>
  );
}

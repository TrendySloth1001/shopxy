import type { Metadata } from "next";
import { getTranslations } from "next-intl/server";
import { LegalDoc, LegalSection } from "@/features/legal/legal-doc";
import { GrievanceOfficerSection } from "@/features/legal/grievance-officer";

export const metadata: Metadata = { title: "Privacy Policy · ShopXY" };

export default async function PrivacyPage() {
  const t = await getTranslations("legal");
  return (
    <LegalDoc title={t("privacy.title")} updated={t("privacy.updated")}>
      <LegalSection heading={t("privacy.overview.heading")}>
        <p>{t("privacy.overview.body")}</p>
      </LegalSection>

      <LegalSection heading={t("privacy.collect.heading")}>
        <p>{t("privacy.collect.body")}</p>
      </LegalSection>

      <LegalSection heading={t("privacy.use.heading")}>
        <p>{t("privacy.use.body")}</p>
      </LegalSection>

      <LegalSection heading={t("privacy.share.heading")}>
        <p>{t("privacy.share.intro")}</p>
        <ul className="flex flex-col gap-xs">
          <li>
            <span className="text-ink">Razorpay Software Private Limited</span> — {t("privacy.share.razorpay")}
          </li>
          <li>
            <span className="text-ink">{t("privacy.share.hostingName")}</span> —{" "}
            {t("privacy.share.hosting")}
          </li>
        </ul>
        <p>{t("privacy.share.outro")}</p>
      </LegalSection>

      <LegalSection heading={t("privacy.retention.heading")}>
        <p>{t("privacy.retention.intro")}</p>
        <ul className="flex flex-col gap-xs">
          <li>
            <span className="text-ink">{t("privacy.retention.invoicesLabel")}</span> — {t("privacy.retention.invoices")}
          </li>
          <li>
            <span className="text-ink">{t("privacy.retention.profileLabel")}</span> — {t("privacy.retention.profile")}
          </li>
          <li>
            <span className="text-ink">{t("privacy.retention.supportLabel")}</span> — {t("privacy.retention.support")}
          </li>
          <li>
            <span className="text-ink">{t("privacy.retention.logsLabel")}</span> — {t("privacy.retention.logs")}
          </li>
        </ul>
      </LegalSection>

      <LegalSection heading={t("privacy.rights.heading")}>
        <p>{t("privacy.rights.body")}</p>
      </LegalSection>

      <LegalSection heading={t("privacy.delete.heading")}>
        <p>{t("privacy.delete.intro")}</p>
        <ul className="flex flex-col gap-xs">
          <li>
            <span className="text-ink">{t("privacy.delete.inAppLabel")}</span> — {t("privacy.delete.inAppPre")}{" "}
            <span className="text-ink">{t("privacy.delete.inAppPath")}</span> {t("privacy.delete.inAppPost")}
          </li>
          <li>
            <span className="text-ink">{t("privacy.delete.byEmailLabel")}</span> — {t("privacy.delete.byEmailPre")}{" "}
            <a className="text-ink underline" href="mailto:privacy@shopxy.app">privacy@shopxy.app</a>{" "}
            {t("privacy.delete.byEmailPost")}
          </li>
        </ul>
        <p>
          <span className="text-ink">{t("privacy.delete.deletedLabel")}</span> {t("privacy.delete.deletedPre")}{" "}
          <span className="text-ink">{t("privacy.delete.deletedDays")}</span>.
        </p>
        <p>
          <span className="text-ink">{t("privacy.delete.keptLabel")}</span> {t("privacy.delete.keptPre")}{" "}
          <a className="text-ink underline" href="mailto:support@shopxy.app">support@shopxy.app</a>{" "}
          {t("privacy.delete.keptPost")}
        </p>
      </LegalSection>

      <LegalSection heading={t("privacy.children.heading")}>
        <p>{t("privacy.children.body")}</p>
      </LegalSection>

      <LegalSection heading={t("privacy.crossBorder.heading")}>
        <p>{t("privacy.crossBorder.body")}</p>
      </LegalSection>

      <LegalSection heading={t("privacy.security.heading")}>
        <p>{t("privacy.security.body")}</p>
      </LegalSection>

      <GrievanceOfficerSection />

      <LegalSection heading={t("privacy.contact.heading")}>
        <p>{t("privacy.contact.body")}</p>
      </LegalSection>
    </LegalDoc>
  );
}

import { getTranslations } from "next-intl/server";
import { LegalSection } from "@/features/legal/legal-doc";

export async function GrievanceOfficerSection() {
  const t = await getTranslations("legal");
  return (
    <LegalSection heading={t("grievance.heading")}>
      <p>{t("grievance.intro")}</p>
      <ul className="flex flex-col gap-xs">
        <li>
          <span className="text-ink">{t("grievance.nameLabel")}</span> {t("grievance.namePlaceholder")}
        </li>
        <li>
          <span className="text-ink">{t("grievance.designationLabel")}</span> {t("grievance.designationPlaceholder")}
        </li>
        <li>
          <span className="text-ink">{t("grievance.emailLabel")}</span> grievance@shopxy.app
        </li>
        <li>
          <span className="text-ink">{t("grievance.phoneLabel")}</span> {t("grievance.phonePlaceholder")}
        </li>
        <li>
          <span className="text-ink">{t("grievance.addressLabel")}</span> {t("grievance.addressPlaceholder")}
        </li>
      </ul>
      <p>
        {t.rich("grievance.sla", {
          strong: (chunks) => <span className="text-ink">{chunks}</span>,
        })}
      </p>
    </LegalSection>
  );
}

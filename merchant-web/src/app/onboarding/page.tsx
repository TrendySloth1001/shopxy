import type { Metadata } from "next";
import { OnboardingForm } from "@/features/onboarding/onboarding-form";

export const metadata: Metadata = {
  title: "Set up your shop · ShopXY Merchant",
};

export default function OnboardingPage() {
  return <OnboardingForm />;
}

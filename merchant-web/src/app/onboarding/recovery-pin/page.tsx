import type { Metadata } from "next";
import { RecoveryPinSetupForm } from "@/features/onboarding/recovery-pin-setup-form";

export const metadata: Metadata = {
  title: "Set up a recovery PIN · ShopXY Merchant",
};

export default function RecoveryPinSetupPage() {
  return <RecoveryPinSetupForm />;
}

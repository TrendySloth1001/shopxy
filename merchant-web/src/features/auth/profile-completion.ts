import type { AuthUser } from "./types";

/**
 * Profile-completion model. The fields here are the ones that make an invoice
 * look professional + let a customer reach the shop — kept in lockstep with the
 * Flutter `profileCompletion` helper so both apps show the same percentage.
 */
const FIELDS: { label: string; get: (u: AuthUser) => string | null | undefined }[] = [
  { label: "Name", get: (u) => u.name },
  { label: "Photo", get: (u) => u.avatarUrl },
  { label: "Phone", get: (u) => u.phoneNumber },
  { label: "Shop name", get: (u) => u.shopName },
  { label: "Address", get: (u) => u.shopAddress },
  { label: "City", get: (u) => u.shopCity },
  { label: "State", get: (u) => u.shopState },
  { label: "State code", get: (u) => u.shopStateCode },
  { label: "PIN code", get: (u) => u.shopPinCode },
  { label: "GSTIN", get: (u) => u.shopGstin },
  { label: "PAN", get: (u) => u.shopPan },
  { label: "UPI ID", get: (u) => u.upiVpa },
];

export type ProfileCompletion = {
  percent: number;
  filled: number;
  total: number;
  /** Labels of the fields still empty. */
  missing: string[];
};

export function profileCompletion(user: AuthUser): ProfileCompletion {
  const states = FIELDS.map((f) => ({ label: f.label, filled: !!f.get(user)?.trim() }));
  const filled = states.filter((s) => s.filled).length;
  const total = states.length;
  return {
    percent: Math.round((filled / total) * 100),
    filled,
    total,
    missing: states.filter((s) => !s.filled).map((s) => s.label),
  };
}

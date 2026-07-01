import type { AuthUser } from "./types";

/**
 * Profile-completion model. The fields here are the ones that make an invoice
 * look professional + let a customer reach the shop — kept in lockstep with the
 * Flutter `profileCompletion` helper so both apps show the same percentage.
 *
 * `key` is a stable message-catalog key (resolved against `auth.field.<key>` at
 * the render site); the array holds no display strings.
 */
const FIELDS: { key: string; get: (u: AuthUser) => string | null | undefined }[] = [
  { key: "name", get: (u) => u.name },
  { key: "photo", get: (u) => u.avatarUrl },
  { key: "phone", get: (u) => u.phoneNumber },
  { key: "shopName", get: (u) => u.shopName },
  { key: "address", get: (u) => u.shopAddress },
  { key: "city", get: (u) => u.shopCity },
  { key: "state", get: (u) => u.shopState },
  { key: "stateCode", get: (u) => u.shopStateCode },
  { key: "pinCode", get: (u) => u.shopPinCode },
  { key: "gstin", get: (u) => u.shopGstin },
  { key: "pan", get: (u) => u.shopPan },
  { key: "upiId", get: (u) => u.upiVpa },
];

export type ProfileCompletion = {
  percent: number;
  filled: number;
  total: number;
  /** Message-catalog keys (`auth.field.<key>`) of the fields still empty. */
  missing: string[];
};

export function profileCompletion(user: AuthUser): ProfileCompletion {
  const states = FIELDS.map((f) => ({ key: f.key, filled: !!f.get(user)?.trim() }));
  const filled = states.filter((s) => s.filled).length;
  const total = states.length;
  return {
    percent: Math.round((filled / total) * 100),
    filled,
    total,
    missing: states.filter((s) => !s.filled).map((s) => s.key),
  };
}

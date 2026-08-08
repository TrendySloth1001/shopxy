import "server-only";

/**
 * The account the environment switcher is shown to — the customer-web mirror
 * of merchant-web's `shared/config/developer.ts` and the Flutter apps'
 * `kDeveloperEmail`.
 *
 * `server-only` on purpose. The gate is enforced in the route handler, and the
 * UI infers its visibility from that endpoint 404ing, so this address never
 * ships in the client bundle.
 */
export const DEVELOPER_EMAIL = "nkumawat1010@gmail.com";

export function isDeveloperAccount(email: string | null | undefined): boolean {
  return !!email && email.trim().toLowerCase() === DEVELOPER_EMAIL;
}

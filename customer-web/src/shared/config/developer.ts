import "server-only";

export const DEVELOPER_EMAIL = "nkumawat1010@gmail.com";

export function isDeveloperAccount(email: string | null | undefined): boolean {
  return !!email && email.trim().toLowerCase() === DEVELOPER_EMAIL;
}

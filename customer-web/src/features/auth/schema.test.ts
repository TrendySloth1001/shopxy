import { describe, expect, it } from "vitest";
import { passwordSchema, loginSchema, registerSchema } from "./schema";

describe("passwordSchema", () => {
  it("requires ≥8 chars with at least one letter and one digit", () => {
    expect(passwordSchema.safeParse("abc12345").success).toBe(true);
    expect(passwordSchema.safeParse("short1").success).toBe(false);
    expect(passwordSchema.safeParse("abcdefgh").success).toBe(false);
    expect(passwordSchema.safeParse("12345678").success).toBe(false);
  });
});

describe("loginSchema", () => {
  it("trims and validates the email and requires a password", () => {
    const ok = loginSchema.safeParse({ email: "  a@b.co  ", password: "x" });
    expect(ok.success).toBe(true);
    if (ok.success) expect(ok.data.email).toBe("a@b.co");
    expect(loginSchema.safeParse({ email: "nope", password: "x" }).success).toBe(false);
    expect(loginSchema.safeParse({ email: "a@b.co", password: "" }).success).toBe(false);
  });
});

describe("registerSchema", () => {
  const valid = {
    name: "Asha",
    email: "asha@example.com",
    password: "abc12345",
    confirmPassword: "abc12345",
    acceptedTerms: true as const,
    acceptedPrivacy: true as const,
  };

  it("accepts a complete, consenting registration", () => {
    expect(registerSchema.safeParse(valid).success).toBe(true);
  });
  it("rejects mismatched passwords", () => {
    expect(registerSchema.safeParse({ ...valid, confirmPassword: "different1" }).success).toBe(false);
  });
  it("requires both terms and privacy consent (DPDP)", () => {
    expect(registerSchema.safeParse({ ...valid, acceptedTerms: false }).success).toBe(false);
    expect(registerSchema.safeParse({ ...valid, acceptedPrivacy: false }).success).toBe(false);
  });
});

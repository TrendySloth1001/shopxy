import { describe, expect, it } from "vitest";
import { formatINR, formatINR2 } from "./money";
import { formatRelativeTime, formatDateTime } from "./datetime";
import { authUserSchema } from "@/features/auth/types";

describe("money", () => {
  it("formats rupees with the Indian grouping", () => {
    expect(formatINR(0)).toBe("₹0");
    expect(formatINR(150000)).toBe("₹1,50,000");
    expect(formatINR2(1234.5)).toBe("₹1,234.50");
  });
});

describe("formatRelativeTime", () => {
  it("handles null/invalid", () => {
    expect(formatRelativeTime(null)).toBe("—");
    expect(formatRelativeTime("not-a-date")).toBe("—");
  });
  it("buckets recent timestamps", () => {
    const now = Date.now();
    expect(formatRelativeTime(new Date(now - 30_000).toISOString())).toBe("just now");
    expect(formatRelativeTime(new Date(now - 5 * 60_000).toISOString())).toBe("5m ago");
    expect(formatRelativeTime(new Date(now - 3 * 3_600_000).toISOString())).toBe("3h ago");
    expect(formatRelativeTime(new Date(now - 2 * 86_400_000).toISOString())).toBe("2d ago");
  });
  it("falls back to an absolute date past a week", () => {
    const old = new Date(Date.now() - 30 * 86_400_000).toISOString();
    expect(formatRelativeTime(old)).toBe(formatDateTime(old));
  });
});

describe("authUserSchema", () => {
  it("parses a minimal /auth/me payload and defaults shopPermissions", () => {
    const u = authUserSchema.parse({
      id: 1,
      email: "a@b.c",
      name: "A",
      role: "OWNER",
      createdAt: "2026-01-01T00:00:00Z",
    });
    expect(u.shopPermissions).toEqual([]);
    expect(u.isPlatformAdmin).toBe(false);
  });
  it("rejects a non-merchant role value", () => {
    expect(() =>
      authUserSchema.parse({ id: 1, email: "a@b.c", name: "A", role: "ADMIN", createdAt: "x" }),
    ).toThrow();
  });
});

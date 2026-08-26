import { describe, expect, it } from "vitest";
import { formatRelativeTime, formatDateTime } from "./datetime";
import { authUserSchema } from "@/features/auth/types";

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

describe("formatDateTime", () => {
  it("handles null/invalid", () => {
    expect(formatDateTime(null)).toBe("—");
    expect(formatDateTime("not-a-date")).toBe("—");
  });
});

describe("authUserSchema", () => {
  it("parses a minimal /auth/me payload and defaults the optional fields", () => {
    const u = authUserSchema.parse({
      id: 1,
      email: "a@b.c",
      name: "A",
      role: "CUSTOMER",
      createdAt: "2026-01-01T00:00:00Z",
    });
    expect(u.shopPermissions).toEqual([]);
    expect(u.isPlatformAdmin).toBe(false);
    expect(u.emailNotifications).toBe(true);
  });
  it("accepts both OWNER and CUSTOMER roles", () => {
    const base = { id: 1, email: "a@b.c", name: "A", createdAt: "x" };
    expect(authUserSchema.parse({ ...base, role: "OWNER" }).role).toBe("OWNER");
    expect(authUserSchema.parse({ ...base, role: "CUSTOMER" }).role).toBe("CUSTOMER");
  });
  it("rejects an unknown role value", () => {
    expect(() =>
      authUserSchema.parse({ id: 1, email: "a@b.c", name: "A", role: "ADMIN", createdAt: "x" }),
    ).toThrow();
  });
});

import { zNum } from "./zod";
import { cartResponseSchema } from "@/features/cart/types";

describe("zNum", () => {
  it("passes plain numbers through", () => {
    expect(zNum.parse(499)).toBe(499);
  });
  it("coerces Prisma Decimal strings", () => {
    expect(zNum.parse("499.00")).toBe(499);
    expect(zNum.parse("0.5")).toBe(0.5);
  });
  it("keeps null/undefined semantics under .nullish()", () => {
    expect(zNum.nullish().parse(null)).toBeNull();
    expect(zNum.nullish().parse(undefined)).toBeUndefined();
  });
  it("rejects non-numeric strings", () => {
    expect(() => zNum.parse("abc")).toThrow();
  });
  it("parses a cart line whose money fields arrive as Decimal strings", () => {
    const parsed = cartResponseSchema.parse({
      data: [
        {
          id: 1,
          productId: 2,
          quantity: "2.00",
          updatedAt: "2026-06-11T00:00:00Z",
          product: {
            id: 2,
            name: "Test",
            mrp: "999.00",
            sellingPrice: "499.00",
            taxPercent: "18.00",
            stockQuantity: "10.00",
            isActive: true,
            isPublished: true,
            images: [],
            shop: { id: 1, name: "S", slug: "s" },
          },
        },
      ],
    });
    expect(parsed.data[0].product.sellingPrice).toBe(499);
    expect(parsed.data[0].quantity).toBe(2);
  });
});

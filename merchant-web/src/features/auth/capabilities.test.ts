import { describe, expect, it } from "vitest";
import type { AuthUser } from "./types";
import { areaForPath, canManage, canView, isShopOwner } from "./capabilities";

function user(partial: Partial<AuthUser>): AuthUser {
  return {
    id: 1,
    email: "x@y.z",
    name: "X",
    role: "OWNER",
    isPlatformAdmin: false,
    emailNotifications: true,
    createdAt: "2026-01-01T00:00:00Z",
    shopPermissions: [],
    ...partial,
  } as AuthUser;
}

describe("shop capabilities", () => {
  it("owner bypasses every check", () => {
    const owner = user({ shopRole: "OWNER", shopPermissions: [] });
    expect(isShopOwner(owner)).toBe(true);
    expect(canView(owner, "products")).toBe(true);
    expect(canManage(owner, "team")).toBe(true);
  });

  it("null/undefined user can do nothing", () => {
    expect(canView(null, "products")).toBe(false);
    expect(canManage(undefined, "products")).toBe(false);
    expect(isShopOwner(null)).toBe(false);
  });

  it("staff is gated by their grants; manage implies view", () => {
    const staff = user({ shopRole: "STAFF", shopPermissions: ["products:view", "orders:manage"] });
    expect(canView(staff, "products")).toBe(true);
    expect(canManage(staff, "products")).toBe(false);
    expect(canView(staff, "orders")).toBe(true); // manage implies view
    expect(canManage(staff, "orders")).toBe(true);
    expect(canView(staff, "reports")).toBe(false);
  });
});

describe("areaForPath", () => {
  it("maps dashboard sections to permission areas", () => {
    expect(areaForPath("/dashboard")).toBe("dashboard");
    expect(areaForPath("/dashboard/products")).toBe("products");
    expect(areaForPath("/dashboard/products/42/edit")).toBe("products");
    expect(areaForPath("/dashboard/invoices/7")).toBe("invoices");
    expect(areaForPath("/dashboard/quotations")).toBe("invoices");
    expect(areaForPath("/dashboard/returns")).toBe("orders");
    expect(areaForPath("/dashboard/reports")).toBe("reports");
    expect(areaForPath("/dashboard/analytics/insights")).toBe("reports");
    expect(areaForPath("/dashboard/team")).toBe("team");
  });

  it("returns null for ungated routes", () => {
    expect(areaForPath("/dashboard/profile")).toBeNull();
    expect(areaForPath("/dashboard/settings")).toBeNull();
    expect(areaForPath("/dashboard/categories")).toBeNull();
  });
});

import { describe, expect, it } from "vitest";
import { hasRight, normalizeRights, summariseRights } from "./permissions";

describe("hasRight", () => {
  it("matches an exact grant", () => {
    expect(hasRight(["products:view"], "products:view")).toBe(true);
    expect(hasRight(["products:view"], "orders:view")).toBe(false);
  });
  it("manage implies view", () => {
    expect(hasRight(["products:manage"], "products:view")).toBe(true);
    expect(hasRight(["products:view"], "products:manage")).toBe(false);
  });
});

describe("normalizeRights", () => {
  it("adds the implied :view for every :manage, de-dupes and sorts", () => {
    expect(normalizeRights(["orders:manage", "products:view", "orders:manage"])).toEqual([
      "orders:manage",
      "orders:view",
      "products:view",
    ]);
  });
});

describe("summariseRights", () => {
  it("summarises viewable areas, collapsing past three", () => {
    expect(summariseRights([])).toBe("No access");
    expect(summariseRights(["products:view", "orders:manage"])).toBe("Products, Orders");
    expect(
      summariseRights(["products:view", "orders:view", "invoices:view", "stock:view"]),
    ).toMatch(/\+1$/);
  });
});

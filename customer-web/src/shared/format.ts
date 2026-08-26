const inrWhole = new Intl.NumberFormat("en-IN", {
  style: "currency",
  currency: "INR",
  maximumFractionDigits: 0,
  minimumFractionDigits: 0,
});

const inrDecimal = new Intl.NumberFormat("en-IN", {
  style: "currency",
  currency: "INR",
  maximumFractionDigits: 2,
  minimumFractionDigits: 2,
});

export function formatINR(
  value: number,
  opts: { decimals?: 0 | 2 } = {},
): string {
  if (!Number.isFinite(value)) return "₹0";
  const n = opts.decimals === 2 ? value : Math.round(value);
  return opts.decimals === 2 ? inrDecimal.format(n) : inrWhole.format(n);
}

export function formatINRCompact(value: number): string {
  if (!Number.isFinite(value)) return "₹0";
  const n = Math.round(value);
  if (Math.abs(n) >= 1_00_00_000) {
    const cr = n / 1_00_00_000;
    return `₹${cr % 1 === 0 ? cr.toFixed(0) : cr.toFixed(1)}Cr`;
  }
  if (Math.abs(n) >= 1_00_000) {
    const l = n / 1_00_000;
    return `₹${l % 1 === 0 ? l.toFixed(0) : l.toFixed(1)}L`;
  }
  if (Math.abs(n) >= 1_000) {
    const k = n / 1_000;
    return `₹${k % 1 === 0 ? k.toFixed(0) : k.toFixed(1)}K`;
  }
  return `₹${n.toLocaleString("en-IN")}`;
}

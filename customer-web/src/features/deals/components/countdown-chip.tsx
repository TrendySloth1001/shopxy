"use client";

import { useEffect, useState } from "react";

/** Formats remaining milliseconds as HH:MM:SS; clamps to 00:00:00 when elapsed. */
function format(ms: number): string {
  let s = Math.max(0, Math.floor(ms / 1000));
  const h = Math.floor(s / 3600);
  s -= h * 3600;
  const m = Math.floor(s / 60);
  s -= m * 60;
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${pad(h)}:${pad(m)}:${pad(s)}`;
}

/**
 * Self-ticking countdown chip. Reads the earliest `endAt` ISO timestamp from
 * the flash-deals list; ticks every second client-side. Mirrors the Flutter
 * `_DealsPageState._ticker` logic in `deals_page.dart`.
 */
export function CountdownChip({ endAtMs }: { endAtMs: number }) {
  const [now, setNow] = useState(() => Date.now());

  useEffect(() => {
    const id = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(id);
  }, []);

  const remaining = endAtMs - now;
  if (remaining <= 0 && endAtMs > 0) return null;

  return (
    <span className="rounded-xs bg-ink px-sm py-[3px] font-mono text-[12px] font-bold tabular-nums text-timer-text">
      {format(remaining)}
    </span>
  );
}

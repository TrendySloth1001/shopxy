#!/usr/bin/env bash
# Design-token leak guard. Fails (exit 1) when a value we've tokenized reappears
# as a raw literal, so the design system stays single-sourced over time.
#
# Run from the repo root:  bash scripts/check-design-tokens.sh
# Wire into CI or a pre-commit hook to enforce.
#
# Sections are added per tokenization phase. A clean tree exits 0.
set -uo pipefail
cd "$(dirname "$0")/.."

fail=0
report() { # <message>  (reads offending lines from stdin)
  local msg="$1" lines
  lines="$(cat)"
  if [ -n "$lines" ]; then
    echo "✗ TOKEN LEAK — $msg"
    echo "$lines" | sed 's/^/    /'
    fail=1
  fi
}

# ── Phase 1: Typography ──────────────────────────────────────────────────────
# Flutter: weight-only overrides must use the AppTextWeight accessor
# (.medium/.semibold/.bold/.extraBold/.black), not raw .copyWith(fontWeight:).
for app in frontend customer; do
  grep -rnE "\.copyWith\(\s*fontWeight:\s*FontWeight\.(w500|w600|w700|w800|w900)\s*,?\s*\)" \
    "$app/lib" --include='*.dart' 2>/dev/null \
    | grep -vE 'app_text_styles\.dart|app_typography\.dart' \
    | report "$app: weight-only .copyWith(fontWeight:) — use .bold/.semibold/.extraBold/etc."
done

# Web: sizes with a token equivalent must use the token
# (text-nano/micro/caption or text-body-{sm,md,lg}), not an arbitrary value.
for app in merchant-web customer-web; do
  grep -rnE 'text-\[(9|9\.5|10|11|12|14|16)px\]|text-\[0\.625rem\]' \
    "$app/src" 2>/dev/null \
    | report "$app: arbitrary text size with a token — use text-nano/micro/caption/body-*"
done

# ── Phase 2: Color ───────────────────────────────────────────────────────────
# The rating/flash accent (#E05A2A) must use the token, not a raw literal.
grep -rniE 'E05A2A' customer/lib --include='*.dart' 2>/dev/null \
  | grep -v 'app_colors\.dart' \
  | report "customer(Flutter): #E05A2A — use AppColors.flashAccent"
grep -rniE '\[#e05a2a\]|#e05a2a' customer-web/src 2>/dev/null \
  | grep -viE 'tokens\.ts|globals\.css' \
  | report "customer-web: #E05A2A — use the flash-accent utility"

# The category-tint palette lives in ONE source per platform (first colour of
# the set is the canary): AppColors.categoryTints / CATEGORY_TINTS.
grep -rniE 'E3E8F4' customer/lib --include='*.dart' 2>/dev/null \
  | grep -v 'app_colors\.dart' \
  | report "customer(Flutter): category tint hex — use AppColors.categoryTints"
grep -rniE 'E3E8F4' customer-web/src 2>/dev/null \
  | grep -v 'category-tints\.ts' \
  | report "customer-web: category tint hex — import CATEGORY_TINTS"

if [ "$fail" -eq 0 ]; then
  echo "✓ design tokens: no leaks"
fi
exit $fail

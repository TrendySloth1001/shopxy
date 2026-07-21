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
# check <message> <offending-lines>
# NOTE: pass grep output via command substitution — do NOT pipe into this
# function; a piped call runs it in a subshell and the fail flag is lost.
check() {
  local msg="$1" lines="$2"
  if [ -n "$lines" ]; then
    echo "✗ TOKEN LEAK — $msg"
    echo "$lines" | sed 's/^/    /'
    fail=1
  fi
}

# ── Phase 1: Typography ──────────────────────────────────────────────────────
for app in frontend customer; do
  check "$app: weight-only .copyWith(fontWeight:) — use .bold/.semibold/.extraBold/etc." \
    "$(grep -rnE "\.copyWith\(\s*fontWeight:\s*FontWeight\.(w500|w600|w700|w800|w900)\s*,?\s*\)" \
       "$app/lib" --include='*.dart' 2>/dev/null | grep -vE 'app_text_styles\.dart|app_typography\.dart')"
done
for app in merchant-web customer-web; do
  check "$app: arbitrary text size with a token — use text-nano/micro/caption/body-*" \
    "$(grep -rnE 'text-\[(9|9\.5|10|11|12|14|16)px\]|text-\[0\.625rem\]' "$app/src" 2>/dev/null)"
done

# ── Phase 2: Color ───────────────────────────────────────────────────────────
check "customer(Flutter): #E05A2A — use AppColors.flashAccent" \
  "$(grep -rniE 'E05A2A' customer/lib --include='*.dart' 2>/dev/null | grep -v 'app_colors\.dart')"
check "customer-web: #E05A2A — use the flash-accent utility" \
  "$(grep -rniE '\[#e05a2a\]|#e05a2a' customer-web/src 2>/dev/null | grep -viE 'tokens\.ts|globals\.css')"
check "customer(Flutter): category tint hex — use AppColors.categoryTints" \
  "$(grep -rniE 'E3E8F4' customer/lib --include='*.dart' 2>/dev/null | grep -v 'app_colors\.dart')"
check "customer-web: category tint hex — import CATEGORY_TINTS" \
  "$(grep -rniE 'E3E8F4' customer-web/src 2>/dev/null | grep -v 'category-tints\.ts')"

# ── Phase 3: Spacing ─────────────────────────────────────────────────────────
for app in frontend customer; do
  check "$app: SizedBox gap with a scale value — use AppSizes.xxs/xs/sm/…" \
    "$(grep -rnE 'SizedBox\((height|width): (2|4|8|12|16|20|24|32|48|64)\)' "$app/lib" --include='*.dart' 2>/dev/null)"
done
check "web: 2px spacing nudge — use the -xxs token" \
  "$(grep -rnE '(^|[" `({>-])(m[trblxy]?|p[trblxy]?|gap(-[xy])?|space-[xy]|inset(-[xy])?|translate-[xy]|top|bottom|left|right)-\[2px\]' \
     customer-web/src merchant-web/src 2>/dev/null)"

if [ "$fail" -eq 0 ]; then
  echo "✓ design tokens: no leaks"
fi
exit $fail

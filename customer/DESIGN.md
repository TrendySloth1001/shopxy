# Shopxy Customer App — Design Rules

These are the **non-negotiable rules** for the customer app. Sourced
from Material 3, Apple HIG, NN/g, Baymard Institute, and *Refactoring
UI*. If a screen violates one, fix the screen — not the rule.

---

## 1. Tokens only — no magic numbers

| Use                                            | Never use         |
| ---------------------------------------------- | ----------------- |
| `AppSizes.lg`                                  | `16` in EdgeInsets|
| `AppColors.brand`                              | `Color(0xFF1E8E5A)`|
| `AppShapes.squircle(AppSizes.radiusMd)`        | hand-rolled border-radius |
| `AppDurations.medium`                          | `Duration(milliseconds: 250)`|
| `theme.textTheme.titleMedium`                  | `fontSize: 16`    |

If a token does not exist for what you need, **add it** to the
constants/theme file. Do not inline.

## 2. One primary action per screen

The CTA is solid black (`AppButton.primary`). Everything else is
secondary, ghost, or destructive. If you're tempted to put two primary
buttons in the same view, you've split the intent — pick one.

## 3. Tap targets ≥ 48dp

Material's minimum. Anything below feels broken on a real phone.
Buttons, list rows, icon buttons — all 48dp tall.

## 4. Loading uses skeletons, not spinners

`AppShimmer` blocks should mirror the final layout. Spinners are
reserved for inside buttons (where the layout is already fixed) and
for full-screen route transitions where there's nothing to skeletonize
yet.

## 5. Empty states have illustration + action

Never ship a blank screen with "No items." Every empty state shows:
an illustration or large icon, a one-line headline, a one-line
explanation, a primary CTA that moves the user forward.

## 6. Errors are actionable

"Something went wrong" alone is forbidden. Every error must offer the
user a way out: retry, go back, contact support. Use
`AppErrorView` with an `onRetry` callback or a route action.

## 7. Confirm destructive actions

Remove from cart, cancel order, delete address, sign out → bottom
sheet confirmation. Never destructive on first tap.

## 8. Snackbars (not dialogs) for non-blocking feedback

3-second auto-dismiss, single line, no actions unless the action is
"Undo" (cart removals only). Use `showAppSnackbar(context, ...)`.

## 9. Numbers use tabular figures

Prices, quantities, order numbers, dates that align in lists — all
must use `FontFeature.tabularFigures()` so columns don't shimmy. Use
`AppPriceText` for currency.

## 10. Motion: 200–300ms, ease-out

Tokens in `AppDurations`. Respect `MediaQuery.disableAnimations` (it's
on for users who set Reduce Motion in OS settings).

## 11. E-commerce-specific (from Baymard)

- **Product card**: image first (≥ 60% of card height), price
  prominent, title second. Wishlist heart top-right.
- **Out of stock**: muted card + "Sold out" badge. Add-to-cart
  disabled, not hidden — users still need the info.
- **Cart row**: quantity stepper always visible (don't hide behind
  tap-to-edit). Remove is destructive — confirm.
- **Checkout**: address selected before payment. Total breakdown
  itemised — subtotal, tax, delivery, total. The "Pay" button shows
  the amount in its label.
- **Order placed**: thank-you screen with the order number, an ETA,
  and a "Track order" CTA. Never just bounce back to the cart.
- **Search**: recent searches in chips. Empty state "Try a category
  or product name." Autocomplete from third character.

## 12. Pull-to-refresh on every list

Without exception. Even if the list is short. Users expect it.

## 13. Safe-area + thumb-zone respect

Primary CTAs sit in the bottom third (thumb zone). Body content stays
out of the notch/dynamic-island region — wrap in `SafeArea` when
there's no AppBar.

## 14. Forms

Label above the field. Helper text or inline error below. One field
per row (don't put two short fields side-by-side unless the screen is
explicitly two-column — `AppBreakpoints.tablet+`).

## 15. Date & relative time

- **In lists**: relative ("2h ago", "yesterday", "3 days ago").
- **On detail pages**: absolute ("23 May 2026, 4:12 PM").
- Use one DateFormat constant per file; never re-instantiate in build.

---

## Reference reading
- Material 3 — m3.material.io
- Apple HIG — developer.apple.com/design/human-interface-guidelines
- NN/g e-commerce — nngroup.com/topic/ecommerce
- Baymard Institute — baymard.com/research
- *Refactoring UI* — refactoringui.com (Adam Wathan, Steve Schoger)

When in doubt, check Baymard's e-commerce checklist before adding a
screen — they've tested everything we'd think to ship.

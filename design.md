# ShopXY Design System — Token Reference & Rules

**This is the single source of truth for visual styling in both Flutter apps
(`frontend/` merchant + `customer/`).** No raw colors, spacing numbers, radii,
font sizes, durations, shadows, or breakpoints may appear in feature code.
Everything routes through the token classes below.

Both apps carry an **identical token API** (same class + member names). Only the
package prefix differs:

| | Merchant (`frontend/`) | Customer (`customer/`) |
|---|---|---|
| package | `package:shopxy/...` | `package:shopxy_customer/...` |

When you add or change a token, **change it in BOTH apps** (the apps are separate
Flutter projects with duplicated shared code — see `CLAUDE.md`).

---

## The token classes

| Concern | Class | File |
|---|---|---|
| Colors | `AppColors` | `shared/theme/app_colors.dart` |
| Typography | `AppTypography` → `Theme.of(context).textTheme` | `shared/theme/app_typography.dart` |
| Shapes / corners | `AppShapes` | `shared/theme/app_shapes.dart` |
| Shadows / elevation | `AppShadows` | `shared/theme/app_shadows.dart` |
| Spacing / radius / icon / sizes | `AppSizes` | `shared/constants/app_sizes.dart` |
| Motion durations | `AppDurations` | `shared/constants/app_durations.dart` |
| Responsive breakpoints | `AppBreakpoints` | `shared/constants/app_breakpoints.dart` |

---

## 1. Colors — `AppColors`

**Never** write `Color(0xFF...)`, `Color.fromARGB(...)`, or a bare `Colors.red`
in feature code. Use a semantic token. For one-off opacity, use
`AppColors.<token>.withValues(alpha: x)` — do not hand-mix a new hex.

**Inks (text + icons):** `black` (warm near-black `#14181D`, the default ink),
`white`, `muted` (secondary text), `subtle` (tertiary/placeholder), `disabled`,
`hairline` (border `#14181D` @ 12%), `surfaceTint` (hover/pressed wash).

**Surfaces:** `canvas` (page bg `#F8F7F3`), `white` (cards/sheets), `pageTint`
(legacy alias), `heroPanel` (illustration backdrop).

**Brand:** `brand` (emerald `#1E8E5A`), `brandStrong`, `brandSoft` (chip fills).

**Status (each with a `…Soft` fill):** `success`/`successSoft`,
`warning`/`warningSoft`, `error`/`errorSoft`, `info`/`infoSoft`.

**Editorial accents (tag entity classes — vendors/parties/categories), each with a
`…Soft`:** `accentTeal`, `accentIndigo`, `accentAmber`, `accentRose`.

**Merchant-only:** `flashDeal`/`flashDealSoft`/`flashDealSoftAlt`, `whatsapp`.

### Allowed exceptions
- `Colors.transparent` is fine (it is not a brand color).
- `AppColors.*.withValues(alpha:)` for genuinely one-off translucency.
- Color *parameters* threaded from a parent (e.g. `final Color accent;`) — the
  literal must originate from an `AppColors` token at the call site, not inline.

### Mapping cheat-sheet (common raw → token)
| Raw | Token |
|---|---|
| `Colors.white`, `Color(0xFFFFFFFF)` | `AppColors.white` |
| `Colors.black`, `Color(0xFF000000)`, `Color(0xFF14181D)` | `AppColors.black` |
| `Colors.grey[600]`, mid greys for text | `AppColors.muted` |
| `Colors.grey[400]`, placeholder greys | `AppColors.subtle` |
| `Colors.grey[300]`, dividers/borders | `AppColors.hairline` |
| `Colors.green` / emerald | `AppColors.brand` |
| `Colors.red` (errors) | `AppColors.error` |
| `Colors.orange`/amber (warnings) | `AppColors.warning` |
| `Colors.blue` (info) | `AppColors.info` |
| page background greys | `AppColors.canvas` |

---

## 2. Typography — `Theme.of(context).textTheme`

**Never** set a raw `fontSize:` or `fontWeight:` to build a text style. Use a
named style from the theme, then `.copyWith(color: …)` only when the color must
differ from the default ink.

```dart
Text('x', style: Theme.of(context).textTheme.titleMedium)
Text('x', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted))
```

Scale (weights/letter-spacing already baked into `AppTypography`):
`displayLarge/Medium/Small` (w700) · `headlineLarge/Medium` (w700) /
`headlineSmall` (w600) · `titleLarge/Medium/Small` (w600) ·
`bodyLarge/Medium/Small` (height 1.4) · `labelLarge/Medium` (w600) · `labelSmall`.

- Font family is Inter via `google_fonts` — never hardcode `fontFamily`.
- `fontWeight` is allowed **only** as a `.copyWith(fontWeight: FontWeight.wXXX)`
  tweak on an existing theme style, and prefer the style whose weight already
  matches. A standalone `TextStyle(fontSize: 14, fontWeight: …)` is a violation.

---

## 3. Spacing, radius, icon & fixed sizes — `AppSizes`

**Never** put a raw number in `EdgeInsets`, `SizedBox`, `Padding`, `gap`,
`BorderRadius`, or icon `size:`. Snap to the scale.

**Spacing scale:** `xs 4` · `sm 8` · `md 12` · `lg 16` · `xl 20` · `xxl 24` ·
`xxxl 32` · `huge 48` · `massive 64`.

```dart
const EdgeInsets.all(AppSizes.lg)
const EdgeInsets.symmetric(horizontal: AppSizes.lg, vertical: AppSizes.md)
const SizedBox(height: AppSizes.sm)
```

**Radius:** `radiusSm 8` · `radiusMd 12` · `radiusLg 16` · `radiusXl 20` ·
`radiusButton 14` · `radiusInput 14` · `radiusDialog 20` · `radiusFull 100`.
Prefer `AppShapes.squircle(AppSizes.radiusLg)` for container shapes (§4).

**Icon sizes:** `iconSm 16` · `iconMd 20` · `iconLg 24` · `iconXl 32` · `iconHuge 48`.

**Component sizes:** `cardPadding 16` · `bottomSheetRadius 24` · `appBarHeight 56`
· `fabSize 56` · `productThumbSize 48` · `productImageSize 120` · `qrCodeSize 200`.

**Recurring off-scale component sizes** (fixed component dimensions, NOT padding —
use these instead of leaving the raw number):
`fabClearance 96` (scroll-list bottom inset clearing a FAB) ·
`handleWidth 36` / `handleHeight 4` (bottom-sheet drag-handle pill) ·
`avatarXs 36` / `avatarSm 40` / `avatarMd 56` (avatars / icon chips / thumbnails) ·
`tapTargetMin 44` (minimum tap target) ·
`heroHeightSm 160` / `heroHeightMd 180` (GlassHero panel heights) ·
`heroIllustration 130` (GlassHero illustration size).

**Micro radius:** `radiusXs 2` — drag-handle pills, chart bars, tiny badges. Use
this (not a raw `2`) for sub-`radiusSm` rounding; pair with `AppShapes.squircle`
or `BorderRadius.circular` only on these non-card primitives.

### Snapping rule for off-scale numbers
Round to the **nearest** scale token (`6→sm`, `10→md`, `14→lg`, `18→xl`,
`28→xxl/xxxl`). If a value is load-bearing and >8px off every token, that's a
**candidate new token** — report it in the find phase; do not invent it inline.

### Allowed exceptions
- `0` / `EdgeInsets.zero` / `BorderSide(width: 1)` hairlines / `width: 1.4`
  focus rings — sub-pixel structural values are fine as literals.
- True aspect ratios, `flex:`, fractional `widthFactor`, animation `0.0–1.0`
  progress values — these are not spacing and stay as literals.

---

## 4. Shapes / corners — `AppShapes`

Continuous (squircle) corners are the house style. Use:
`AppShapes.squircle(radius, {side})` for `shape:`,
`AppShapes.squircleRadius(radius)` for `borderRadius:`,
`AppShapes.squircleTop(radius)` / `squircleTopRadius(radius)` for sheets.
Pass an `AppSizes.radius*` token as the radius — never a raw number, never a
plain `BorderRadius.circular(n)` for app surfaces.

---

## 5. Shadows / elevation — `AppShadows`

The apps are deliberately flat (hairline borders, not drop shadows). When a
surface must float, use a token list, never an inline `BoxShadow`:
`AppShadows.none` · `AppShadows.floating` (sticky CTAs/chips) ·
`AppShadows.menu` (dropdowns/menus) · `AppShadows.snackbar` (toasts).
Material `elevation:` should stay `0` (the theme enforces this).

---

## 6. Motion — `AppDurations`

**Never** write `Duration(milliseconds: 200)` in feature code:
`micro 100ms` · `short 180ms` · `medium 240ms` (default in-page) ·
`long 320ms` · `snackbar 3s` · `snackbarLong 5s` · `searchDebounce 220ms`.
Honor `MediaQuery.disableAnimations(context)` → `Duration.zero` when set.

---

## 7. Responsive breakpoints — `AppBreakpoints`

**Never** compare against magic widths: `phone 600` · `tablet 840` ·
`desktop 1200` · `contentMaxWidth 720` · `formMaxWidth 520`.

---

## Reviewer / agent checklist

When tokenizing a module, scan for and replace:
1. `Color(0x…)`, `Color.fromARGB`, `Colors.<name>` (except `transparent`) → `AppColors`
2. Raw numbers in `EdgeInsets` / `SizedBox` / `Padding` / `BorderRadius` / icon `size:` → `AppSizes`
3. `TextStyle(fontSize:…)` / standalone `fontWeight:` → `textTheme` style
4. `BorderRadius.circular(n)` on app surfaces → `AppShapes.squircle*`
5. Inline `BoxShadow` → `AppShadows`
6. `Duration(milliseconds:/seconds:)` → `AppDurations`
7. Magic width breakpoints → `AppBreakpoints`

Always ensure the matching `import` is present after editing. Preserve `const`
constructors (the tokens are `const`, so `const` widgets stay `const`). Do not
change behavior, layout intent, or copy — only swap the literal for the token
that reproduces the same value (or the nearest scale token per the snapping rule).
Anything genuinely off-scale that has no token gets **reported, not invented**.

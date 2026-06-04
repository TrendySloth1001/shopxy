/**
 * Design tokens — single source of truth for the customer web app.
 *
 * Ported 1:1 from the Flutter customer app (`customer/lib/shared/theme/*` and
 * `customer/lib/shared/constants/*`). The CSS layer in `globals.css` mirrors
 * these values into Tailwind theme variables; this file is the source used by
 * TypeScript (charts, canvas, inline SVG, JS-driven motion) where a Tailwind
 * class is not available.
 *
 * RULE: never write a raw colour / size / duration in a component. If a value
 * is missing here, add a named token first, then use it. (See CLAUDE.md §9.)
 *
 * NOTE: the merchant web app keeps its own copy of this file (mirroring how the
 * Flutter `frontend/` and `customer/` apps duplicate their tokens). Keep the
 * shared groups in sync; the merchant app additionally defines a flash-deal /
 * whatsapp accent group that this app deliberately omits.
 */

/**
 * Calm, breathable palette designed to *not* attack the eye: warm canvas page,
 * near-black inks (not pure black), refined emerald brand, and a small set of
 * editorial accents for distinguishing entity types.
 */
export const color = {
  /** Inks — text + iconography. */
  ink: {
    /** Primary ink. Warm near-black — kinder than pure #000, still reads black. */
    black: "#14181D",
    /** Pure white reserved for floating surfaces (cards, sheets). */
    white: "#FFFFFF",
    /** Hairline border — warm graphite at ~12% alpha. Grouping is done with
     *  these, not boxes (CLAUDE.md §9b: dividers over boxes). */
    hairline: "#14181D1F",
    /** Even softer wash — hover/pressed surfaces (~4% alpha). */
    surfaceTint: "#14181D0A",
    /** Secondary text. */
    muted: "#6A707A",
    /** Tertiary / placeholder text. */
    subtle: "#98A0AA",
    /** Disabled foreground. */
    disabled: "#C2C7CE",
  },
  /** Surfaces — page background + card surfaces + hero panels. */
  surface: {
    /** Warm parchment global page background. White cards sit on top. */
    canvas: "#F8F7F3",
    /** Slightly cooler tint — legacy alias kept for older callers. */
    pageTint: "#FAFAF7",
    /** Soft panel behind hero illustrations — a half-step deeper than canvas. */
    heroPanel: "#EFEEE7",
  },
  /** Brand — refined emerald; confident, not loud. */
  brand: {
    default: "#1E8E5A",
    strong: "#146A42",
    /** Pale brand wash — chip fills, soft accent surfaces. */
    soft: "#E6F2EC",
  },
  /** Status — soft tones (each pairs a foreground with a soft fill). */
  status: {
    success: "#16A34A",
    successSoft: "#E7F4EC",
    warning: "#B45309",
    warningSoft: "#FAEBD0",
    error: "#B42318",
    errorSoft: "#FCE9E7",
    info: "#1D4ED8",
    infoSoft: "#E3EAFE",
  },
  /** Editorial accents — used sparingly to tag distinct entity classes. */
  accent: {
    teal: "#0E7C8A",
    tealSoft: "#DDF1F3",
    indigo: "#4338CA",
    indigoSoft: "#E5E2FB",
    amber: "#A15C07",
    amberSoft: "#FAE9CC",
    rose: "#B83A6F",
    roseSoft: "#FADFEB",
  },
} as const;

/** Spacing scale (px). 4px base rhythm — matches Tailwind's numeric scale. */
export const space = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 20,
  xxl: 24,
  xxxl: 32,
  huge: 48,
  massive: 64,
} as const;

/** Corner radii (px). Restrained on purpose — nothing chunky (CLAUDE.md §9b). */
export const radius = {
  /** Micro rounding — drag handles, chart bars, tiny badges. */
  xs: 2,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 20,
  button: 14,
  input: 14,
  dialog: 20,
  bottomSheet: 24,
  /** Pill / fully rounded. */
  full: 100,
} as const;

/** Icon sizes (px). */
export const iconSize = {
  sm: 16,
  md: 20,
  lg: 24,
  xl: 32,
  huge: 48,
} as const;

/**
 * Fixed component dimensions that sit *off* the spacing scale on purpose
 * (not padding — actual element sizes).
 */
export const size = {
  appBarHeight: 56,
  fabSize: 56,
  /** Scroll-list bottom inset so the last row clears a floating action button. */
  fabClearance: 96,
  cardPadding: 16,
  /** Bottom-sheet drag-handle pill. */
  handleWidth: 36,
  handleHeight: 4,
  avatarXs: 36,
  avatarSm: 40,
  avatarMd: 56,
  /** Minimum comfortable tap/click target. */
  tapTargetMin: 44,
  heroHeightSm: 160,
  heroHeightMd: 180,
  heroIllustration: 130,
  productThumbSize: 48,
  productImageSize: 120,
  qrCodeSize: 200,
} as const;

/**
 * Responsive breakpoints (px). Mirror Material 3 window-size classes. Used for
 * JS layout decisions and as max-width content rails.
 */
export const breakpoint = {
  /** Below this, compact (phone portrait). */
  phone: 600,
  /** Below this, medium (small tablet / phone landscape). */
  tablet: 840,
  /** Above this, expanded (large tablet / desktop). */
  desktop: 1200,
  /** Max readable width for body copy (60–75 char line length). */
  contentMaxWidth: 720,
  /** Max width for forms (sign-in, address, checkout). */
  formMaxWidth: 520,
} as const;

/** Motion durations (ms). Respect `prefers-reduced-motion` before applying. */
export const duration = {
  /** Micro feedback — ripples, focus rings, toggle thumbs. */
  micro: 100,
  /** Short transitions — selection highlights, chip taps, press feedback. */
  short: 180,
  /** Default for in-page changes — sheet show/hide, drawer, card expand. */
  medium: 240,
  /** Longer reveal — hero/route transitions, expandable sections. */
  long: 320,
  /** Snackbar auto-dismiss (single line). */
  snackbar: 3000,
  /** Toast messages that need a moment to read. */
  snackbarLong: 5000,
  /** Debounce for type-ahead search. */
  searchDebounce: 220,
} as const;

/** Standard easing curve for UI motion. */
export const easing = {
  standard: "cubic-bezier(0.2, 0, 0, 1)",
} as const;

/**
 * Elevation. The UI is deliberately flat — hairline borders group content
 * instead of shadows — but a few floating surfaces need a faint lift. All
 * shadows are warm-black ink at low alpha so they land softly on the canvas.
 */
export const shadow = {
  none: "none",
  /** Whisper — sticky bottom CTA, floating chips. */
  floating: "0 4px 12px rgba(20, 24, 29, 0.04)",
  /** Dropdown / menu / autocomplete panel. */
  menu: "0 8px 20px rgba(20, 24, 29, 0.06)",
  /** Snackbar / toast — readable against any underlying content. */
  snackbar: "0 10px 24px rgba(20, 24, 29, 0.12)",
} as const;

/**
 * Type scale (px) with the weights / tracking / line-heights ported from the
 * Flutter `AppTypography` overrides. Inter throughout.
 */
export const typography = {
  fontFamily: "var(--font-inter), ui-sans-serif, system-ui, sans-serif",
  display: {
    lg: { size: 57, weight: 700, tracking: -0.5, leading: 1.1 },
    md: { size: 45, weight: 700, tracking: -0.5, leading: 1.15 },
    sm: { size: 36, weight: 700, tracking: -0.4, leading: 1.2 },
  },
  headline: {
    lg: { size: 32, weight: 700, tracking: -0.3, leading: 1.25 },
    md: { size: 28, weight: 700, tracking: -0.3, leading: 1.3 },
    sm: { size: 24, weight: 600, tracking: -0.2, leading: 1.33 },
  },
  title: {
    lg: { size: 22, weight: 600, tracking: -0.2, leading: 1.4 },
    md: { size: 16, weight: 600, tracking: 0, leading: 1.5 },
    sm: { size: 14, weight: 600, tracking: 0, leading: 1.4 },
  },
  body: {
    lg: { size: 16, weight: 400, tracking: 0, leading: 1.4 },
    md: { size: 14, weight: 400, tracking: 0, leading: 1.4 },
    sm: { size: 12, weight: 400, tracking: 0, leading: 1.4 },
  },
  label: {
    lg: { size: 14, weight: 600, tracking: 0, leading: 1.2 },
    md: { size: 12, weight: 600, tracking: 0, leading: 1.2 },
  },
} as const;

/** Convenience aggregate — handy for token-table / Storybook style screens. */
export const tokens = {
  color,
  space,
  radius,
  iconSize,
  size,
  breakpoint,
  duration,
  easing,
  shadow,
  typography,
} as const;

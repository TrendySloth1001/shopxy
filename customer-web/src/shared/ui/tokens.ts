export const color = {
  ink: {
    black: "#14181D",
    white: "#FFFFFF",
    hairline: "#14181D1F",
    surfaceTint: "#14181D0A",
    muted: "#6A707A",
    subtle: "#98A0AA",
    disabled: "#C2C7CE",
  },
  surface: {
    canvas: "#F8F7F3",
    pageTint: "#FAFAF7",
    heroPanel: "#EFEEE7",
  },
  brand: {
    default: "#1E8E5A",
    strong: "#146A42",
    soft: "#E6F2EC",
  },
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
  scrim: "rgba(20, 24, 29, 0.40)",

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
  promo: {
    flashFrom: "#FFE3D2",
    flashTo: "#FFD2D2",
    flashAccent: "#E05A2A",
    timerText: "#FFD580",
    spotlight: "#F4F757",
  },
} as const;

export const space = {
  xxs: 2,
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

export const radius = {
  xs: 2,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 20,
  button: 14,
  input: 14,
  dialog: 20,
  bottomSheet: 24,
  full: 100,
} as const;

export const iconSize = {
  sm: 16,
  md: 20,
  lg: 24,
  xl: 32,
  huge: 48,
} as const;

export const size = {
  appBarHeight: 56,
  fabSize: 56,
  fabClearance: 96,
  cardPadding: 16,
  handleWidth: 36,
  handleHeight: 4,
  avatarXs: 36,
  avatarSm: 40,
  avatarMd: 56,
  tapTargetMin: 44,
  heroHeightSm: 160,
  heroHeightMd: 180,
  heroIllustration: 130,
  productThumbSize: 48,
  productImageSize: 120,
  qrCodeSize: 200,
} as const;

export const breakpoint = {
  phone: 600,
  tablet: 840,
  desktop: 1200,
  contentMaxWidth: 720,
  formMaxWidth: 520,
  shellMaxWidth: 1280,
} as const;

export const duration = {
  micro: 100,
  short: 180,
  medium: 240,
  long: 320,
  snackbar: 3000,
  snackbarLong: 5000,
  searchDebounce: 220,
} as const;

export const easing = {
  standard: "cubic-bezier(0.2, 0, 0, 1)",
} as const;

export const shadow = {
  none: "none",
  floating: "0 4px 12px rgba(20, 24, 29, 0.04)",
  menu: "0 8px 20px rgba(20, 24, 29, 0.06)",
  snackbar: "0 10px 24px rgba(20, 24, 29, 0.12)",
} as const;

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
  caption: { size: 11, weight: 400, tracking: 0, leading: 1.35 },
  micro: { size: 10, weight: 400, tracking: 0, leading: 1.3 },
  nano: { size: 9, weight: 400, tracking: 0.2, leading: 1.3 },
} as const;

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

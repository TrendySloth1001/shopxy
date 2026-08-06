/// The single source of truth for the 7 selectable PDF look-and-feels. Each
/// preset is a `{shellId, palette, fonts, borderStyle, density}` config fed
/// into the shared blocks (`./blocks.tsx`) — NOT a bespoke hand-built design
/// per preset. Only the standard 14 PDF base fonts are used (Helvetica/
/// Times/Courier families) so no font files need to be bundled/registered.
export interface TemplatePalette {
  text: string;
  muted: string;
  border: string;
  headerBg: string; // items-table header row fill
  rowAlt: string; // alternating row tint (only used by `colorful`)
  accent: string; // ShellB's header-band fill / ShellA's rule color
  onAccent: string; // text color drawn on top of `accent`
}

export interface TemplateFonts {
  heading: string;
  headingBold: string;
  body: string;
  bodyBold: string;
  bodyOblique: string;
}

export interface TemplateConfig {
  id: string;
  name: string;
  description: string;
  order: number;
  shellId: 'A' | 'B';
  palette: TemplatePalette;
  fonts: TemplateFonts;
  borderStyle: 'hairline' | 'none' | 'bold';
  density: 'normal' | 'compact';
  rowAltStripe: boolean;
}

const HELVETICA: TemplateFonts = {
  heading: 'Helvetica-Bold',
  headingBold: 'Helvetica-Bold',
  body: 'Helvetica',
  bodyBold: 'Helvetica-Bold',
  bodyOblique: 'Helvetica-Oblique',
};

const TIMES: TemplateFonts = {
  heading: 'Times-Bold',
  headingBold: 'Times-Bold',
  body: 'Times-Roman',
  bodyBold: 'Times-Bold',
  bodyOblique: 'Times-Italic',
};

const NEUTRAL_PALETTE: TemplatePalette = {
  text: '#111827',
  muted: '#6B7280',
  border: '#E5E7EB',
  headerBg: '#F3F4F6',
  rowAlt: '#FAFAFA',
  accent: '#111827',
  onAccent: '#FFFFFF',
};

export const TEMPLATE_PRESETS: TemplateConfig[] = [
  {
    id: 'classic',
    name: 'Classic',
    description: "ShopXY's original layout — clean, dense, and familiar.",
    order: 0,
    shellId: 'A',
    palette: NEUTRAL_PALETTE,
    fonts: HELVETICA,
    borderStyle: 'hairline',
    density: 'normal',
    rowAltStripe: false,
  },
  {
    id: 'minimal',
    name: 'Minimal',
    description: 'No borders, generous whitespace, just the essentials.',
    order: 1,
    shellId: 'A',
    palette: { ...NEUTRAL_PALETTE, border: '#FFFFFF', headerBg: '#FFFFFF' },
    fonts: HELVETICA,
    borderStyle: 'none',
    density: 'normal',
    rowAltStripe: false,
  },
  {
    id: 'elegant',
    name: 'Elegant',
    description: 'Serif headings and a centred, refined tone.',
    order: 2,
    shellId: 'A',
    palette: { ...NEUTRAL_PALETTE, headerBg: '#F8F5F0', accent: '#78716C' },
    fonts: TIMES,
    borderStyle: 'hairline',
    density: 'normal',
    rowAltStripe: false,
  },
  {
    id: 'compact',
    name: 'Compact',
    description: 'Tighter rows — fits long item lists on fewer pages.',
    order: 3,
    shellId: 'A',
    palette: NEUTRAL_PALETTE,
    fonts: HELVETICA,
    borderStyle: 'hairline',
    density: 'compact',
    rowAltStripe: false,
  },
  {
    id: 'modern',
    name: 'Modern',
    description: 'A bold header band with your shop name up top.',
    order: 4,
    shellId: 'B',
    palette: { ...NEUTRAL_PALETTE, accent: '#1D4ED8', onAccent: '#FFFFFF' },
    fonts: HELVETICA,
    borderStyle: 'hairline',
    density: 'normal',
    rowAltStripe: false,
  },
  {
    id: 'bold',
    name: 'Bold',
    description: 'A strong solid-colour header band for high contrast.',
    order: 5,
    shellId: 'B',
    palette: { ...NEUTRAL_PALETTE, accent: '#B91C1C', onAccent: '#FFFFFF' },
    fonts: HELVETICA,
    borderStyle: 'bold',
    density: 'normal',
    rowAltStripe: false,
  },
  {
    id: 'colorful',
    name: 'Colorful',
    description: 'A tinted table header with alternating row shading.',
    order: 6,
    shellId: 'B',
    palette: {
      ...NEUTRAL_PALETTE,
      accent: '#047857',
      onAccent: '#FFFFFF',
      headerBg: '#D1FAE5',
      rowAlt: '#ECFDF5',
    },
    fonts: HELVETICA,
    borderStyle: 'hairline',
    density: 'normal',
    rowAltStripe: true,
  },
];

const PRESET_BY_ID = new Map(TEMPLATE_PRESETS.map((p) => [p.id, p]));

export const DEFAULT_TEMPLATE_ID = 'classic';

/// Resolves a stored `pdfTemplateId` to its config — falls back to the
/// default and logs a warning for a retired/unknown id rather than ever
/// failing a real document render over a stale template choice.
export function resolveTemplateConfig(templateId: string | null | undefined): TemplateConfig {
  const id = templateId ?? DEFAULT_TEMPLATE_ID;
  const found = PRESET_BY_ID.get(id);
  if (found) return found;
  if (templateId) {
    // eslint-disable-next-line no-console
    console.warn(`[pdf] Unknown pdfTemplateId "${templateId}" — falling back to "${DEFAULT_TEMPLATE_ID}"`);
  }
  return PRESET_BY_ID.get(DEFAULT_TEMPLATE_ID)!;
}

export function isKnownTemplateId(id: string): boolean {
  return PRESET_BY_ID.has(id);
}

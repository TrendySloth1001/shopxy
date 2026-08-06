import { Document, Page, Text, View } from '@react-pdf/renderer';
import type { PdfDocumentModel } from './model.js';
import type { TemplateConfig } from './presets.js';
import { paginateItemRows } from './paginate.js';
import {
  DeclarationBlock,
  Footer,
  HsnSummaryBlock,
  ItemsTableSlice,
  MetaStrip,
  NoteBlock,
  PartiesRow,
  SignatureQrBlock,
  TitleBlock,
  TotalsBlock,
} from './blocks.js';

const PAGE_PADDING = { top: 40, bottom: 56, left: 40, right: 40 };
// Usable A4 content height (841.89pt) minus the reserved top/bottom padding.
const CONTENT_HEIGHT = 841.89 - PAGE_PADDING.top - PAGE_PADDING.bottom;
const TABLE_HEADER_HEIGHT = 22;
// Generous per-row estimates (item cells can wrap to two lines) — an
// underestimate of capacity only ever costs an occasional un-headered
// spillover page, never clipped content, since react-pdf auto-continues
// overflow onto a fresh page regardless of our chunk boundaries.
const ROW_HEIGHT = { normal: 32, compact: 24 };
// Reserved space for the title/badge/parties/meta block that only appears
// once, above the table, on the first page.
const HEADER_AREA = { A: 230, B: 250 };

function headerAreaHeight(model: PdfDocumentModel, config: TemplateConfig): number {
  let h = HEADER_AREA[config.shellId];
  if (model.metaSecondRow) h += 26;
  return h;
}

function ShellATop({ model, config }: { model: PdfDocumentModel; config: TemplateConfig }) {
  const showBorder = config.borderStyle !== 'none';
  return (
    <>
      <TitleBlock title={model.title} badgeLines={model.titleBadgeLines} config={config} />
      <View
        style={{
          borderBottomWidth: showBorder ? (config.borderStyle === 'bold' ? 1.2 : 1) : 0,
          borderColor: config.palette.border,
          marginBottom: 10,
        }}
      />
      <PartiesRow model={model} config={config} />
    </>
  );
}

function ShellBTop({ model, config }: { model: PdfDocumentModel; config: TemplateConfig }) {
  return (
    <>
      <View
        style={{
          backgroundColor: config.palette.accent,
          paddingVertical: 14,
          paddingHorizontal: PAGE_PADDING.left,
          marginHorizontal: -PAGE_PADDING.left,
          marginTop: -PAGE_PADDING.top,
          marginBottom: 14,
        }}
      >
        <Text style={{ fontFamily: config.fonts.heading, fontSize: 20, color: config.palette.onAccent }}>
          {model.title}
        </Text>
        {model.titleBadgeLines && model.titleBadgeLines.length > 0 && (
          <Text style={{ fontFamily: config.fonts.body, fontSize: 8, color: config.palette.onAccent, marginTop: 3 }}>
            {model.titleBadgeLines.join('   ·   ')}
          </Text>
        )}
      </View>
      <PartiesRow model={model} config={config} />
    </>
  );
}

/// Builds the full multi-page `<Document>` for one document model + template
/// config. Item rows are pre-chunked (see `paginate.ts`) into one `<Page>`
/// per slice, each with the table header re-painted at the top; the
/// trailing blocks (HSN summary/totals/declaration/signature/notes) render
/// in normal flow after the LAST slice, and the footer is `fixed` so it
/// repeats on every page (including any un-planned overflow page) via
/// react-pdf's built-in per-page render prop.
export function renderShellDocument(model: PdfDocumentModel, config: TemplateConfig) {
  const rowHeight = ROW_HEIGHT[config.density];
  const firstPageHeight = CONTENT_HEIGHT - headerAreaHeight(model, config);
  const continuationHeight = CONTENT_HEIGHT - 20;
  const slices = paginateItemRows(model.items.rows, {
    firstPageHeight,
    continuationHeight,
    rowHeight,
    headerHeight: TABLE_HEADER_HEIGHT,
  });
  const Top = config.shellId === 'A' ? ShellATop : ShellBTop;

  return (
    <Document>
      {slices.map((slice, i) => (
        <Page
          key={i}
          size="A4"
          style={{
            paddingTop: PAGE_PADDING.top,
            paddingBottom: PAGE_PADDING.bottom,
            paddingLeft: PAGE_PADDING.left,
            paddingRight: PAGE_PADDING.right,
            fontFamily: config.fonts.body,
          }}
          wrap
        >
          {slice.isFirstPage && <Top model={model} config={config} />}
          {slice.isFirstPage && <MetaStrip model={model} config={config} />}
          <ItemsTableSlice table={model.items} rows={slice.rows} config={config} />
          {slice.isLastPage && (
            <>
              {model.hsnSummary && <HsnSummaryBlock table={model.hsnSummary} config={config} />}
              <TotalsBlock model={model} config={config} />
              {model.declaration && <DeclarationBlock text={model.declaration} config={config} />}
              <SignatureQrBlock model={model} config={config} />
              {model.note && <NoteBlock note={model.note} config={config} />}
            </>
          )}
          <Footer config={config} />
        </Page>
      ))}
    </Document>
  );
}

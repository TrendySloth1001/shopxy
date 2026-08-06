import { Document, Page, Text, View, Image } from '@react-pdf/renderer';
import type { PdfDocumentModel, PdfPartyInfo, PdfTable, PdfTableRow } from './model.js';
import type { TemplateConfig } from './presets.js';
import { paginateItemRows } from './paginate.js';
import { PAGE_PADDING, CONTENT_HEIGHT } from './shells.js';
import {
  DeclarationBlock,
  Footer,
  HsnSummaryBlock,
  NoteBlock,
  TotalsBlock,
} from './blocks.js';

/// The "traditional" preset: a fully-gridded ledger-style layout (every
/// field in its own bordered box), matching the classic accounting-software
/// invoice format still common among Indian small businesses — as opposed
/// to ShellA/ShellB's whitespace-based, mostly-borderless look. Different
/// enough (per-cell borders, a nested info grid, a signature box) that it's
/// its own render path rather than another `{shellId, palette, ...}` config
/// fed into the shared blocks.

const BORDER = '#000000';
const ROW_HEIGHT = 28;
const TABLE_HEADER_HEIGHT = 20;
// Roomier than ShellA/B's header area — the bordered info grid (title +
// 6 ledger rows) takes more vertical space than a plain meta strip.
const HEADER_AREA_HEIGHT = 300;
const FOOTER_BOX_HEIGHT = 70;

function LedgerCell({
  label,
  value,
  last,
  fontFamily,
}: {
  label: string;
  value?: string;
  last?: boolean;
  fontFamily: string;
}) {
  return (
    <View
      style={{
        width: '50%',
        borderRightWidth: last ? 0 : 0.75,
        borderColor: BORDER,
        paddingHorizontal: 4,
        paddingVertical: 3,
      }}
    >
      <Text style={{ fontFamily, fontSize: 8, color: '#111827' }}>{label}</Text>
      <Text style={{ fontFamily, fontSize: 9, color: '#111827', marginTop: 1 }}>{value ?? ' '}</Text>
    </View>
  );
}

function LedgerRow({
  left,
  right,
  fontFamily,
}: {
  left: { label: string; value?: string };
  right: { label: string; value?: string };
  fontFamily: string;
}) {
  return (
    <View style={{ flexDirection: 'row', borderBottomWidth: 0.75, borderColor: BORDER }}>
      <LedgerCell label={left.label} value={left.value} fontFamily={fontFamily} />
      <LedgerCell label={right.label} value={right.value} last fontFamily={fontFamily} />
    </View>
  );
}

function LedgerFullRow({ label, value, fontFamily }: { label: string; value?: string; fontFamily: string }) {
  return (
    <View style={{ paddingHorizontal: 4, paddingVertical: 4 }}>
      <Text style={{ fontFamily, fontSize: 8.5, color: '#111827' }}>
        {label}
        {value ? `: ${value}` : ''}
      </Text>
    </View>
  );
}

function PartyLines({ party, fontFamily, fontFamilyBold }: { party: PdfPartyInfo; fontFamily: string; fontFamilyBold: string }) {
  return (
    <View>
      <Text style={{ fontFamily: fontFamilyBold, fontSize: 10, color: '#111827' }}>{party.name}</Text>
      {party.addressLine && (
        <Text style={{ fontFamily, fontSize: 8.5, color: '#111827', marginTop: 1 }}>{party.addressLine}</Text>
      )}
      {party.gstin && <Text style={{ fontFamily, fontSize: 8.5, color: '#111827' }}>GSTIN: {party.gstin}</Text>}
      {party.pan && <Text style={{ fontFamily, fontSize: 8.5, color: '#111827' }}>PAN: {party.pan}</Text>}
      {party.extraLine && <Text style={{ fontFamily, fontSize: 8.5, color: '#111827' }}>{party.extraLine}</Text>}
    </View>
  );
}

const DOCUMENT_NO_LABEL: Record<PdfDocumentModel['kind'], string> = {
  invoice: 'Invoice No.',
  quotation: 'Quotation No.',
  challan: 'Challan No.',
};

function HeaderBox({ model, config }: { model: PdfDocumentModel; config: TemplateConfig }) {
  const t = model.traditionalMeta;
  const fontFamily = config.fonts.body;
  const fontFamilyBold = config.fonts.bodyBold;
  return (
    <>
      <View style={{ borderBottomWidth: 1, borderColor: BORDER, paddingVertical: 6, alignItems: 'center' }}>
        <Text style={{ fontFamily: config.fonts.heading, fontSize: 13, color: '#111827' }}>{model.title}</Text>
      </View>
      <View style={{ flexDirection: 'row', borderBottomWidth: 1, borderColor: BORDER }}>
        <View style={{ width: '56%', borderRightWidth: 1, borderColor: BORDER, padding: 6 }}>
          {model.shopLabel && (
            <Text style={{ fontFamily: fontFamilyBold, fontSize: 8, color: '#111827', marginBottom: 2 }}>
              {model.shopLabel}
            </Text>
          )}
          <PartyLines party={model.shop} fontFamily={fontFamily} fontFamilyBold={fontFamilyBold} />
          <View style={{ height: 10 }} />
          <Text style={{ fontFamily: fontFamilyBold, fontSize: 8, color: '#111827' }}>
            {model.counterpartyLabel}
          </Text>
          <PartyLines party={model.counterparty} fontFamily={fontFamily} fontFamilyBold={fontFamilyBold} />
        </View>
        <View style={{ width: '44%' }}>
          <LedgerRow
            left={{ label: DOCUMENT_NO_LABEL[model.kind], value: t?.documentNo }}
            right={{ label: 'Dated', value: t?.documentDate }}
            fontFamily={fontFamily}
          />
          <LedgerRow
            left={{ label: 'Delivery Note', value: t?.deliveryNote }}
            right={{ label: 'Mode/Terms of Payment', value: t?.paymentTerms }}
            fontFamily={fontFamily}
          />
          <LedgerRow
            left={{ label: "Buyer's Order No.", value: t?.buyersOrderNo }}
            right={{ label: 'Dated', value: t?.buyersOrderDate }}
            fontFamily={fontFamily}
          />
          <LedgerRow
            left={{ label: 'Dispatch Document No.', value: t?.dispatchDocNo }}
            right={{ label: 'Deliver Note Date', value: t?.dispatchNoteDate }}
            fontFamily={fontFamily}
          />
          <LedgerRow
            left={{ label: 'Dispatched Through', value: t?.dispatchedThrough }}
            right={{ label: 'Destination', value: t?.destination }}
            fontFamily={fontFamily}
          />
          <LedgerFullRow label="Terms of Delivery" value={t?.termsOfDelivery} fontFamily={fontFamily} />
        </View>
      </View>
    </>
  );
}

function GridHeaderRow({ table, fontFamilyBold }: { table: Pick<PdfTable, 'headers' | 'widths'>; fontFamilyBold: string }) {
  return (
    <View
      wrap={false}
      style={{ flexDirection: 'row', borderBottomWidth: 1, borderColor: BORDER, backgroundColor: '#F3F4F6' }}
    >
      {table.headers.map((h, i) => (
        <Text
          key={`${h.text}-${i}`}
          style={{
            width: `${table.widths[i]}%`,
            borderRightWidth: i === table.headers.length - 1 ? 0 : 0.75,
            borderColor: BORDER,
            paddingHorizontal: 3,
            paddingVertical: 4,
            fontFamily: fontFamilyBold,
            fontSize: 7.5,
            color: '#111827',
            textAlign: h.align,
          }}
        >
          {h.text}
        </Text>
      ))}
    </View>
  );
}

function GridDataRow({ row, widths, fontFamily }: { row: PdfTableRow; widths: number[]; fontFamily: string }) {
  return (
    <View
      wrap={false}
      style={{ flexDirection: 'row', borderBottomWidth: 0.75, borderColor: BORDER, minHeight: ROW_HEIGHT }}
    >
      {row.cells.map((c, i) => (
        <Text
          key={i}
          style={{
            width: `${widths[i]}%`,
            borderRightWidth: i === row.cells.length - 1 ? 0 : 0.75,
            borderColor: BORDER,
            paddingHorizontal: 3,
            paddingVertical: 4,
            fontFamily,
            fontSize: 8,
            color: '#111827',
            textAlign: c.align,
          }}
        >
          {c.text}
        </Text>
      ))}
    </View>
  );
}

function FooterBox({ model, config }: { model: PdfDocumentModel; config: TemplateConfig }) {
  return (
    <View
      wrap={false}
      style={{ flexDirection: 'row', borderTopWidth: 1, borderColor: BORDER, minHeight: FOOTER_BOX_HEIGHT }}
    >
      <View style={{ width: '50%', borderRightWidth: 1, borderColor: BORDER, padding: 6 }}>
        <Text style={{ fontFamily: config.fonts.body, fontSize: 8.5, color: '#111827' }}>
          Customer&apos;s seal and Signature
        </Text>
        {model.upiQr && (
          <Image src={model.upiQr.buffer} style={{ width: 56, height: 56, marginTop: 4 }} />
        )}
      </View>
      <View style={{ width: '50%', padding: 6, alignItems: 'flex-end' }}>
        {model.signatureName && (
          <>
            <Text style={{ fontFamily: config.fonts.bodyBold, fontSize: 8.5, color: '#111827' }}>
              {model.signatureName}
            </Text>
            <View style={{ flex: 1 }} />
            <Text style={{ fontFamily: config.fonts.body, fontSize: 8.5, color: '#111827' }}>
              Authorised Signatory
            </Text>
          </>
        )}
      </View>
    </View>
  );
}

export function renderTraditionalDocument(model: PdfDocumentModel, config: TemplateConfig) {
  const firstPageHeight = CONTENT_HEIGHT - HEADER_AREA_HEIGHT;
  const continuationHeight = CONTENT_HEIGHT - 20;
  const slices = paginateItemRows(model.items.rows, {
    firstPageHeight,
    continuationHeight,
    rowHeight: ROW_HEIGHT,
    headerHeight: TABLE_HEADER_HEIGHT,
  });

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
          <View style={{ flex: 1, borderWidth: 1, borderColor: BORDER }}>
            {slice.isFirstPage && <HeaderBox model={model} config={config} />}
            <GridHeaderRow table={model.items} fontFamilyBold={config.fonts.bodyBold} />
            {slice.rows.map((row, ri) => (
              <GridDataRow key={ri} row={row} widths={model.items.widths} fontFamily={config.fonts.body} />
            ))}
            {slice.isLastPage && (
              <View style={{ minHeight: ROW_HEIGHT, borderBottomWidth: 0.75, borderColor: BORDER }} />
            )}
            <View style={{ flex: 1 }} />
            {slice.isLastPage && <FooterBox model={model} config={config} />}
          </View>
          {slice.isLastPage && (
            <>
              {model.hsnSummary && <HsnSummaryBlock table={model.hsnSummary} config={config} />}
              <TotalsBlock model={model} config={config} />
              {model.declaration && <DeclarationBlock text={model.declaration} config={config} />}
              {model.note && <NoteBlock note={model.note} config={config} />}
            </>
          )}
          <Footer config={config} />
        </Page>
      ))}
    </Document>
  );
}

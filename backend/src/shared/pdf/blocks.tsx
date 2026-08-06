import { StyleSheet, Text, View, Image } from '@react-pdf/renderer';
import type {
  PdfDocumentModel,
  PdfMetaField,
  PdfPartyInfo,
  PdfTable,
  PdfTableRow,
} from './model.js';
import type { TemplateConfig } from './presets.js';

const styles = StyleSheet.create({
  row: { flexDirection: 'row' },
  spaceBetween: { flexDirection: 'row', justifyContent: 'space-between' },
  col: { flexDirection: 'column' },
  cell: { paddingHorizontal: 2, paddingVertical: 3 },
});

/// ---------- Title + badge lines ----------
export function TitleBlock({
  title,
  badgeLines,
  config,
}: {
  title: string;
  badgeLines?: string[];
  config: TemplateConfig;
}) {
  return (
    <View style={[styles.spaceBetween, { alignItems: 'flex-start', marginBottom: 6 }]}>
      <Text
        style={{
          fontFamily: config.fonts.heading,
          fontSize: 18,
          color: config.palette.text,
        }}
      >
        {title}
      </Text>
      {badgeLines && badgeLines.length > 0 && (
        <View style={{ alignItems: 'flex-end' }}>
          {badgeLines.map((line) => (
            <Text
              key={line}
              style={{ fontFamily: config.fonts.body, fontSize: 7, color: config.palette.muted }}
            >
              {line}
            </Text>
          ))}
        </View>
      )}
    </View>
  );
}

/// ---------- Shop block (left) + Counterparty block (right) ----------
function PartyBlock({
  heading,
  headingSize,
  party,
  align,
  config,
}: {
  heading?: string;
  headingSize: number;
  party: PdfPartyInfo;
  align: 'left' | 'right';
  config: TemplateConfig;
}) {
  const textAlign = align;
  return (
    <View style={{ alignItems: align === 'right' ? 'flex-end' : 'flex-start' }}>
      {heading && (
        <Text
          style={{
            fontFamily: config.fonts.bodyBold,
            fontSize: 9,
            color: config.palette.text,
            marginBottom: 2,
            textAlign,
          }}
        >
          {heading}
        </Text>
      )}
      <Text
        style={{
          fontFamily: config.fonts.headingBold,
          fontSize: headingSize,
          color: config.palette.text,
          textAlign,
        }}
      >
        {party.name}
      </Text>
      {party.addressLine && (
        <Text
          style={{ fontFamily: config.fonts.body, fontSize: 9, color: config.palette.muted, textAlign, marginTop: 2 }}
        >
          {party.addressLine}
        </Text>
      )}
      {party.gstin && (
        <Text style={{ fontFamily: config.fonts.body, fontSize: 9, color: config.palette.muted, textAlign }}>
          GSTIN: {party.gstin}
        </Text>
      )}
      {party.pan && (
        <Text style={{ fontFamily: config.fonts.body, fontSize: 9, color: config.palette.muted, textAlign }}>
          PAN: {party.pan}
        </Text>
      )}
      {!party.gstin && !party.pan && party.extraLine && (
        <Text style={{ fontFamily: config.fonts.body, fontSize: 9, color: config.palette.muted, textAlign }}>
          {party.extraLine}
        </Text>
      )}
    </View>
  );
}

export function PartiesRow({ model, config }: { model: PdfDocumentModel; config: TemplateConfig }) {
  return (
    <View style={[styles.spaceBetween, { marginBottom: 10 }]}>
      <PartyBlock
        heading={model.shopLabel}
        headingSize={11}
        party={model.shop}
        align="left"
        config={config}
      />
      <PartyBlock
        heading={model.counterpartyLabel}
        headingSize={11}
        party={model.counterparty}
        align="right"
        config={config}
      />
    </View>
  );
}

/// ---------- Meta strip ----------
function MetaRow({ fields, config }: { fields: PdfMetaField[]; config: TemplateConfig }) {
  return (
    <View style={[styles.row, { marginBottom: 6 }]}>
      {fields.map((f) => (
        <View key={f.label} style={{ flex: 1 }}>
          <Text
            style={{
              fontFamily: config.fonts.body,
              fontSize: 7,
              color: config.palette.muted,
              textTransform: 'uppercase',
            }}
          >
            {f.label}
          </Text>
          <Text
            style={{ fontFamily: config.fonts.bodyBold, fontSize: 9, color: config.palette.text, marginTop: 1 }}
          >
            {f.value}
          </Text>
        </View>
      ))}
    </View>
  );
}

export function MetaStrip({ model, config }: { model: PdfDocumentModel; config: TemplateConfig }) {
  const showBorders = config.borderStyle !== 'none';
  return (
    <View
      style={{
        borderTopWidth: showBorders ? (config.borderStyle === 'bold' ? 1.2 : 0.7) : 0,
        borderBottomWidth: showBorders ? (config.borderStyle === 'bold' ? 1.2 : 0.7) : 0,
        borderColor: config.palette.border,
        paddingVertical: 6,
        marginBottom: 10,
      }}
    >
      <MetaRow fields={model.meta} config={config} />
      {model.metaSecondRow && <MetaRow fields={model.metaSecondRow} config={config} />}
    </View>
  );
}

/// ---------- Items / HSN summary table ----------
function TableHeaderRow({ table, config }: { table: Pick<PdfTable, 'headers' | 'widths'>; config: TemplateConfig }) {
  return (
    <View
      style={[
        styles.row,
        {
          backgroundColor: config.palette.headerBg,
          paddingVertical: 4,
        },
      ]}
      fixed={false}
    >
      {table.headers.map((h, i) => (
        <Text
          key={`${h.text}-${i}`}
          style={[
            styles.cell,
            {
              width: `${table.widths[i]}%`,
              fontFamily: config.fonts.bodyBold,
              fontSize: 7.5,
              color: config.palette.text,
              textAlign: h.align,
            },
          ]}
        >
          {h.text}
        </Text>
      ))}
    </View>
  );
}

function TableDataRow({
  row,
  widths,
  index,
  config,
}: {
  row: PdfTableRow;
  widths: number[];
  index: number;
  config: TemplateConfig;
}) {
  const striped = config.rowAltStripe && index % 2 === 1;
  const showBorders = config.borderStyle !== 'none';
  return (
    <View
      style={[
        styles.row,
        {
          borderBottomWidth: showBorders ? 0.7 : 0,
          borderColor: config.palette.border,
          backgroundColor: striped ? config.palette.rowAlt : undefined,
          paddingVertical: config.density === 'compact' ? 2 : 4,
        },
      ]}
    >
      {row.cells.map((c, i) => (
        <Text
          key={i}
          style={[
            styles.cell,
            {
              width: `${widths[i]}%`,
              fontFamily: config.fonts.body,
              fontSize: config.density === 'compact' ? 7.5 : 8,
              color: config.palette.text,
              textAlign: c.align,
            },
          ]}
        >
          {c.text}
        </Text>
      ))}
    </View>
  );
}

export function ItemsTableSlice({
  table,
  rows,
  config,
}: {
  table: PdfTable;
  rows: PdfTableRow[];
  config: TemplateConfig;
}) {
  return (
    <View style={{ marginBottom: 6 }}>
      <TableHeaderRow table={table} config={config} />
      {rows.map((r, i) => (
        <TableDataRow key={i} row={r} widths={table.widths} index={i} config={config} />
      ))}
    </View>
  );
}

export function HsnSummaryBlock({ table, config }: { table: PdfTable; config: TemplateConfig }) {
  return (
    <View style={{ marginBottom: 10 }}>
      <Text style={{ fontFamily: config.fonts.bodyBold, fontSize: 9, color: config.palette.text, marginBottom: 4 }}>
        HSN Summary
      </Text>
      <TableHeaderRow table={table} config={config} />
      {table.rows.map((r, i) => (
        <TableDataRow key={i} row={r} widths={table.widths} index={i} config={config} />
      ))}
    </View>
  );
}

/// ---------- Totals block ----------
export function TotalsBlock({ model, config }: { model: PdfDocumentModel; config: TemplateConfig }) {
  return (
    <View style={{ marginBottom: 8 }}>
      <View style={{ width: '45%', marginLeft: '55%' }}>
        {model.totals.map((t, i) => (
          <View
            key={i}
            style={[
              styles.spaceBetween,
              {
                paddingVertical: 2,
                borderTopWidth: t.bold ? (config.borderStyle === 'none' ? 0 : 1) : 0,
                borderColor: config.palette.border,
                marginTop: t.bold ? 3 : 0,
                paddingTop: t.bold ? 4 : 2,
              },
            ]}
          >
            <Text
              style={{
                fontFamily: t.bold ? config.fonts.bodyBold : config.fonts.body,
                fontSize: 9,
                color: config.palette.text,
              }}
            >
              {t.label}
            </Text>
            <Text
              style={{
                fontFamily: t.bold ? config.fonts.bodyBold : config.fonts.body,
                fontSize: 9,
                color: config.palette.text,
              }}
            >
              {t.value}
            </Text>
          </View>
        ))}
      </View>
      {model.amountInWords && (
        <Text
          style={{
            fontFamily: config.fonts.bodyOblique,
            fontSize: 9,
            color: config.palette.muted,
            marginTop: 6,
          }}
        >
          {model.amountInWords}
        </Text>
      )}
    </View>
  );
}

/// ---------- Statutory declaration / disclaimer ----------
export function DeclarationBlock({ text, config }: { text: string; config: TemplateConfig }) {
  return (
    <Text
      style={{
        fontFamily: config.fonts.bodyOblique,
        fontSize: 8,
        color: config.palette.muted,
        marginBottom: 8,
      }}
    >
      {text}
    </Text>
  );
}

/// ---------- UPI QR (left) + supplier signature (right) ----------
export function SignatureQrBlock({ model, config }: { model: PdfDocumentModel; config: TemplateConfig }) {
  if (!model.upiQr && !model.signatureName) return null;
  return (
    <View style={[styles.spaceBetween, { alignItems: 'flex-end', marginBottom: 8 }]}>
      <View>
        {model.upiQr && (
          <>
            <Image src={model.upiQr.buffer} style={{ width: 90, height: 90 }} />
            <Text style={{ fontFamily: config.fonts.body, fontSize: 8, color: config.palette.muted, marginTop: 4 }}>
              {model.upiQr.caption}
            </Text>
            {model.upiQr.vpaLine && (
              <Text style={{ fontFamily: config.fonts.body, fontSize: 8, color: config.palette.muted }}>
                {model.upiQr.vpaLine}
              </Text>
            )}
          </>
        )}
      </View>
      {model.signatureName && (
        <View style={{ alignItems: 'flex-end', width: 200 }}>
          <Text style={{ fontFamily: config.fonts.bodyBold, fontSize: 9, color: config.palette.text }}>
            {model.signatureName}
          </Text>
          <View
            style={{
              borderTopWidth: 0.7,
              borderColor: config.palette.border,
              width: 200,
              marginTop: 30,
              marginBottom: 4,
            }}
          />
          <Text style={{ fontFamily: config.fonts.body, fontSize: 8, color: config.palette.muted }}>
            Authorised Signatory
          </Text>
        </View>
      )}
    </View>
  );
}

/// ---------- Notes ----------
export function NoteBlock({ note, config }: { note: string; config: TemplateConfig }) {
  return (
    <View style={{ marginBottom: 4 }}>
      <Text style={{ fontFamily: config.fonts.bodyBold, fontSize: 8, color: config.palette.text, marginBottom: 2 }}>
        Notes
      </Text>
      <Text style={{ fontFamily: config.fonts.body, fontSize: 8, color: config.palette.muted }}>{note}</Text>
    </View>
  );
}

/// ---------- Footer with "Page X of Y" ----------
export function Footer({ config }: { config: TemplateConfig }) {
  return (
    <Text
      fixed
      style={{
        position: 'absolute',
        bottom: 24,
        left: 40,
        right: 40,
        fontFamily: config.fonts.body,
        fontSize: 7,
        color: config.palette.muted,
        textAlign: 'center',
      }}
      render={({ pageNumber, totalPages }) =>
        `This is a computer-generated document.   Page ${pageNumber} of ${totalPages}`
      }
    />
  );
}

/// Column-set builder shared by the three document renderers (invoice /
/// quotation / challan), across both their react-pdf and PDFKit paths.
///
/// A merchant who isn't GST-registered — or who never entered an HSN code —
/// used to get those columns anyway, filled with `-` and `0.00`. That isn't
/// merely noise: a GST column on a non-GST bill reads as a claim that tax was
/// accounted for. Columns are therefore declared with a `show` flag and
/// omitted outright when they don't apply, with the width they free up handed
/// to the `flex` column (the item-name one) so the table still spans the page.
///
/// Lives outside `shared/pdf/` on purpose: that subtree is ESM-only (see
/// `pdfEngineLoader.ts`) and the three renderers are CommonJS.
export interface PdfColumn<T> {
  header: string;
  /// PDFKit-style absolute point width. Kept widths always re-sum to the
  /// `totalWidth` passed to [buildPdfColumns], so callers can keep their
  /// existing percentage / x-offset maths untouched.
  width: number;
  align: 'left' | 'right';
  cell: (row: T, index: number) => string;
  /// Omitted entirely when false. Absent or true = always shown.
  show?: boolean;
  /// Absorbs the width freed by omitted columns. Exactly one column per table
  /// should set this — without it the slack is simply dropped and the table
  /// stops short of the right margin.
  flex?: boolean;
}

export interface PdfColumnSet<T> {
  headers: string[];
  widths: number[];
  align: (index: number) => 'left' | 'right';
  /// The visible cell values for one row, in the same order as `headers`.
  row: (item: T, index: number) => string[];
}

/// `totalWidth` is passed in rather than summed from `columns` because some
/// declared columns are mutually exclusive (IGST vs CGST+SGST) — their widths
/// must not both count toward the table's span.
export function buildPdfColumns<T>(
  totalWidth: number,
  columns: PdfColumn<T>[],
): PdfColumnSet<T> {
  const kept = columns.filter((c) => c.show !== false);
  const keptTotal = kept.reduce((sum, c) => sum + c.width, 0);
  const slack = totalWidth - keptTotal;
  const flexIndex = kept.findIndex((c) => c.flex);
  const widths = kept.map((c, i) => (i === flexIndex ? c.width + slack : c.width));
  const aligns = kept.map((c) => c.align);
  return {
    headers: kept.map((c) => c.header),
    widths,
    align: (index) => aligns[index] ?? 'left',
    row: (item, index) => kept.map((c) => c.cell(item, index)),
  };
}

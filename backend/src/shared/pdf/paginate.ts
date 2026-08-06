import type { PdfTableRow } from './model.js';

/// react-pdf has no "repeat this header row on every page a table spans"
/// primitive (no `fixed`-position trick works cleanly once page 1 has extra
/// content above the table that later pages don't). Instead we pre-chunk
/// the item rows into explicit per-page slices — each slice becomes its own
/// `<Page>` with the header row painted at the top — using a fixed row
/// height per density, same approach PDFKit's own `y + rowH > 720` check
/// used, just computed up front instead of during a single imperative draw.
export interface ItemPageSlice {
  rows: PdfTableRow[];
  isFirstPage: boolean;
  isLastPage: boolean;
}

export interface PaginateOptions {
  /// Usable page height, in points, remaining for item rows on the FIRST
  /// page — i.e. after the title/shop/party/meta blocks that only appear
  /// once. Continuation pages get `continuationHeight` instead.
  firstPageHeight: number;
  /// Usable height for item rows on a continuation page (just margin +
  /// table header, no shop/party/meta blocks repeated).
  continuationHeight: number;
  rowHeight: number;
  headerHeight: number;
}

export function paginateItemRows(rows: PdfTableRow[], opts: PaginateOptions): ItemPageSlice[] {
  if (rows.length === 0) {
    return [{ rows: [], isFirstPage: true, isLastPage: true }];
  }
  const slices: PdfTableRow[][] = [];
  let remaining = rows;
  let isFirst = true;
  while (remaining.length > 0) {
    const available = isFirst ? opts.firstPageHeight : opts.continuationHeight;
    const capacity = Math.max(1, Math.floor((available - opts.headerHeight) / opts.rowHeight));
    slices.push(remaining.slice(0, capacity));
    remaining = remaining.slice(capacity);
    isFirst = false;
  }
  return slices.map((slice, i) => ({
    rows: slice,
    isFirstPage: i === 0,
    isLastPage: i === slices.length - 1,
  }));
}

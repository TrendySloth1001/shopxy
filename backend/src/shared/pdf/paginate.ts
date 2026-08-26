import type { PdfTableRow } from './model.js';

export interface ItemPageSlice {
  rows: PdfTableRow[];
  isFirstPage: boolean;
  isLastPage: boolean;
}

export interface PaginateOptions {
  firstPageHeight: number;
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

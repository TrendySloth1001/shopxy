export interface PdfColumn<T> {
  header: string;
  width: number;
  align: 'left' | 'right';
  cell: (row: T, index: number) => string;
  show?: boolean;
  flex?: boolean;
}

export interface PdfColumnSet<T> {
  headers: string[];
  widths: number[];
  align: (index: number) => 'left' | 'right';
  row: (item: T, index: number) => string[];
}

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

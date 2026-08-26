import prisma from '../../infra/db/prisma.js';
import {
  ALL_SERIES,
  DEFAULT_SCHEMES,
  resolveScheme,
  formatDocNo,
  previewNextSeq,
  setCounterStart,
  type Series,
  type SchemeFields,
} from '../../shared/numbering/sequences.js';

export interface SchemeDto extends SchemeFields {
  series: Series;
  isCustom: boolean;
  nextPreview: string;
  nextSeq: number;
  financialYear: string;
}

export class NumberingService {
  async listSchemesForShop(shopId: number): Promise<SchemeDto[]> {
    const rows = await prisma.numberingScheme.findMany({ where: { shopId } });
    const bySeries = new Map(rows.map((r) => [r.series as Series, r]));
    const out: SchemeDto[] = [];
    for (const series of ALL_SERIES) {
      const row = bySeries.get(series);
      const scheme: SchemeFields = row
        ? {
            prefix: row.prefix,
            suffix: row.suffix,
            separator: row.separator,
            padding: row.padding,
            resetYearly: row.resetYearly,
          }
        : DEFAULT_SCHEMES[series];
      const { seq, financialYear } = await previewNextSeq(shopId, series, prisma);
      out.push({
        series,
        ...scheme,
        isCustom: !!row,
        nextPreview: formatDocNo(scheme, seq, financialYear),
        nextSeq: seq,
        financialYear,
      });
    }
    return out;
  }

  async upsertScheme(
    shopId: number,
    series: Series,
    patch: Partial<SchemeFields>,
  ): Promise<SchemeDto> {
    const current = await resolveScheme(shopId, series, prisma);
    const next: SchemeFields = { ...current, ...patch };
    const row = await prisma.numberingScheme.upsert({
      where: { shopId_series: { shopId, series } },
      create: { shopId, series, ...next },
      update: { ...next },
    });
    const { seq, financialYear } = await previewNextSeq(shopId, series, prisma);
    return {
      series,
      prefix: row.prefix,
      suffix: row.suffix,
      separator: row.separator,
      padding: row.padding,
      resetYearly: row.resetYearly,
      isCustom: true,
      nextPreview: formatDocNo(next, seq, financialYear),
      nextSeq: seq,
      financialYear,
    };
  }

  async setNextNumber(shopId: number, series: Series, startAt: number): Promise<SchemeDto> {
    await setCounterStart(shopId, series, startAt, prisma);
    const [current, row, { seq, financialYear }] = await Promise.all([
      resolveScheme(shopId, series, prisma),
      prisma.numberingScheme.findUnique({ where: { shopId_series: { shopId, series } } }),
      previewNextSeq(shopId, series, prisma),
    ]);
    return {
      series,
      ...current,
      isCustom: !!row,
      nextPreview: formatDocNo(current, seq, financialYear),
      nextSeq: seq,
      financialYear,
    };
  }
}

export const numberingService = new NumberingService();

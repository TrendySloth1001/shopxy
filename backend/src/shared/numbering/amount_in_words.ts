/**
 * Indian-numbering amount-to-words formatter.
 *
 * Used by the invoice service to pre-render the "Rupees ... only" line that
 * sits above the GST summary on the printed PDF. Indian convention uses
 * lakh (1,00,000) and crore (1,00,00,000) rather than the Western thousand /
 * million groupings, and paise is the standard 1/100 fractional rupee unit.
 *
 * Pure — no I/O, no Prisma. Safe to call from anywhere in the request path.
 */

const ONES = [
  'Zero', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
  'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
  'Seventeen', 'Eighteen', 'Nineteen',
];

const TENS = [
  '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety',
];

/// Converts an integer 0–999 into words. Used by the Indian-system wrapper
/// below — caller is responsible for grouping (thousand / lakh / crore).
function under1000(n: number): string {
  if (n < 0 || n > 999) throw new Error(`under1000: out of range (${n})`);
  if (n < 20) return ONES[n];
  if (n < 100) {
    const t = Math.floor(n / 10);
    const o = n % 10;
    return o === 0 ? TENS[t] : `${TENS[t]} ${ONES[o]}`;
  }
  const h = Math.floor(n / 100);
  const r = n % 100;
  return r === 0
    ? `${ONES[h]} Hundred`
    : `${ONES[h]} Hundred ${under1000(r)}`;
}

/// Indian-system integer-to-words. 1,23,45,678 → "One Crore Twenty Three
/// Lakh Forty Five Thousand Six Hundred Seventy Eight".
function intToWordsIndian(n: number): string {
  if (!Number.isFinite(n)) throw new Error('intToWordsIndian: not finite');
  if (n < 0) return `Minus ${intToWordsIndian(-n)}`;
  if (n === 0) return 'Zero';

  const parts: string[] = [];
  const crore = Math.floor(n / 10000000);
  const remAfterCrore = n % 10000000;
  const lakh = Math.floor(remAfterCrore / 100000);
  const remAfterLakh = remAfterCrore % 100000;
  const thousand = Math.floor(remAfterLakh / 1000);
  const remainder = remAfterLakh % 1000;

  if (crore > 0) parts.push(`${intToWordsIndian(crore)} Crore`);
  if (lakh > 0) parts.push(`${under1000(lakh)} Lakh`);
  if (thousand > 0) parts.push(`${under1000(thousand)} Thousand`);
  if (remainder > 0) parts.push(under1000(remainder));

  return parts.join(' ');
}

/// Formats a rupee amount as "Rupees X and Paise Y only". The input is a
/// Number or numeric string — both come up because Prisma returns Decimal
/// for the invoice total. Anything past two decimal places is rounded to
/// match the displayed amount on the invoice.
export function amountInWords(amount: number | string): string {
  const n = typeof amount === 'string' ? Number(amount) : amount;
  if (!Number.isFinite(n)) return 'Rupees Zero only';

  // Half-away-from-zero rounding on the paise so we agree with the
  // displayed total after `roundOff` has been applied.
  const sign = n < 0 ? -1 : 1;
  const abs = Math.abs(n);
  const totalPaise = Math.round(abs * 100);
  const rupees = Math.floor(totalPaise / 100);
  const paise = totalPaise % 100;

  const rupeesWords = intToWordsIndian(rupees);
  const prefix = sign < 0 ? 'Minus ' : '';
  if (paise === 0) {
    return `${prefix}Rupees ${rupeesWords} only`;
  }
  const paiseWords = under1000(paise);
  return `${prefix}Rupees ${rupeesWords} and Paise ${paiseWords} only`;
}

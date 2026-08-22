/**
 * Indian-format validators + lookup tables.
 *
 * Pure regex / table helpers — no I/O. Used by request validation
 * (auth, party/vendor create/update, invoice place-of-supply) and by
 * the PDF generator (to render the GSTIN/PAN if present).
 */

/// GSTIN is 15 chars: state(2) + PAN(10) + entity(1) + Z + checksum(1).
/// Example: 27ABCDE1234F1Z5
export const GSTIN_REGEX = /^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[0-9A-Z]{1}Z[0-9A-Z]{1}$/;

/// PAN: 5 alpha + 4 digit + 1 alpha. Example: ABCDE1234F
export const PAN_REGEX = /^[A-Z]{5}[0-9]{4}[A-Z]{1}$/;

/// Indian PIN: 6 digits, first digit 1-9.
export const PINCODE_REGEX = /^[1-9][0-9]{5}$/;

/// Indian mobile: 10 digits starting 6-9. Accepts an optional +91 / 0 prefix.
export const PHONE_REGEX = /^(?:\+?91[-\s]?|0)?[6-9][0-9]{9}$/;

/// HSN/SAC: 4, 6 or 8 digits.
export const HSN_REGEX = /^[0-9]{4}(?:[0-9]{2}(?:[0-9]{2})?)?$/;

/// UPI VPA: handle@psp. Loose check — UPI VPA spec is fairly free-form.
export const UPI_VPA_REGEX = /^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z][a-zA-Z]{2,64}$/;

export interface IndianState {
  code: string; // 2-digit GST state code
  name: string;
}

/// GST state codes per the GST notification. Used to:
///   1. Render the state drop-down on Party/Vendor forms.
///   2. Determine IGST vs CGST/SGST: if shop.stateCode !== placeOfSupply.stateCode, IGST applies.
///   3. Validate the first two chars of a GSTIN against the state code on the row.
export const INDIAN_STATES: IndianState[] = [
  { code: '01', name: 'Jammu and Kashmir' },
  { code: '02', name: 'Himachal Pradesh' },
  { code: '03', name: 'Punjab' },
  { code: '04', name: 'Chandigarh' },
  { code: '05', name: 'Uttarakhand' },
  { code: '06', name: 'Haryana' },
  { code: '07', name: 'Delhi' },
  { code: '08', name: 'Rajasthan' },
  { code: '09', name: 'Uttar Pradesh' },
  { code: '10', name: 'Bihar' },
  { code: '11', name: 'Sikkim' },
  { code: '12', name: 'Arunachal Pradesh' },
  { code: '13', name: 'Nagaland' },
  { code: '14', name: 'Manipur' },
  { code: '15', name: 'Mizoram' },
  { code: '16', name: 'Tripura' },
  { code: '17', name: 'Meghalaya' },
  { code: '18', name: 'Assam' },
  { code: '19', name: 'West Bengal' },
  { code: '20', name: 'Jharkhand' },
  { code: '21', name: 'Odisha' },
  { code: '22', name: 'Chhattisgarh' },
  { code: '23', name: 'Madhya Pradesh' },
  { code: '24', name: 'Gujarat' },
  { code: '25', name: 'Daman and Diu' },
  { code: '26', name: 'Dadra and Nagar Haveli' },
  { code: '27', name: 'Maharashtra' },
  { code: '28', name: 'Andhra Pradesh (Before Division)' },
  { code: '29', name: 'Karnataka' },
  { code: '30', name: 'Goa' },
  { code: '31', name: 'Lakshadweep' },
  { code: '32', name: 'Kerala' },
  { code: '33', name: 'Tamil Nadu' },
  { code: '34', name: 'Puducherry' },
  { code: '35', name: 'Andaman and Nicobar Islands' },
  { code: '36', name: 'Telangana' },
  { code: '37', name: 'Andhra Pradesh (New)' },
  { code: '38', name: 'Ladakh' },
];

const STATE_CODE_BY_NAME = new Map(INDIAN_STATES.map((s) => [s.name.toLowerCase(), s.code]));
const STATE_NAME_BY_CODE = new Map(INDIAN_STATES.map((s) => [s.code, s.name]));

export function stateCodeFromName(name: string | null | undefined): string | null {
  if (!name) return null;
  return STATE_CODE_BY_NAME.get(name.toLowerCase()) ?? null;
}

export function stateNameFromCode(code: string | null | undefined): string | null {
  if (!code) return null;
  return STATE_NAME_BY_CODE.get(code) ?? null;
}

/// True when `code` is a real 2-digit GST state code from the notification
/// table. Used to validate a place-of-supply / GSTIN-prefix state code beyond
/// the `\d{2}` shape (GST-11) — a code like "99" is two digits but not a state.
export function isValidStateCode(code: string | null | undefined): boolean {
  if (!code) return false;
  return STATE_NAME_BY_CODE.has(code);
}

/// Base-36 alphabet the GSTIN check digit is computed over.
const GSTIN_CHARSET = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';

/// The 15th character of a GSTIN is a mod-36 check digit over the first 14.
/// Each character's base-36 value is multiplied by an alternating 1/2 weight,
/// the product's base-36 digits are summed, and the digit that rounds the
/// total up to a multiple of 36 is the check character.
export function gstinCheckDigit(first14: string): string | null {
  if (first14.length !== 14) return null;
  let sum = 0;
  for (let i = 0; i < 14; i++) {
    const value = GSTIN_CHARSET.indexOf(first14[i]);
    if (value < 0) return null;
    const product = value * (i % 2 === 0 ? 1 : 2);
    sum += Math.floor(product / 36) + (product % 36);
  }
  return GSTIN_CHARSET[(36 - (sum % 36)) % 36];
}

/// Full GSTIN validation: shape, a real state code in the first two digits,
/// and the mod-36 check digit.
///
/// [GSTIN_REGEX] alone accepts any 15 characters in the right shape, so a
/// mistyped GSTIN passes it. That matters where the value is self-declared by
/// a buyer claiming input credit: an invalid GSTIN on a tax invoice is the
/// recipient's ITC denied and the supplier's return mismatched, and neither
/// party finds out until filing.
export function isValidGstin(value: string | null | undefined): boolean {
  if (!value) return false;
  const gstin = value.trim().toUpperCase();
  if (!GSTIN_REGEX.test(gstin)) return false;
  if (!isValidStateCode(gstin.slice(0, 2))) return false;
  return gstinCheckDigit(gstin.slice(0, 14)) === gstin[14];
}

/// Predicate: do we cross a state boundary (IGST) or stay inside one (CGST+SGST)?
/// Defaults to intrastate when either side is unknown — safer than mis-charging IGST.
export function isInterstateSupply(
  shopStateCode: string | null | undefined,
  placeOfSupplyStateCode: string | null | undefined,
): boolean {
  if (!shopStateCode || !placeOfSupplyStateCode) return false;
  return shopStateCode !== placeOfSupplyStateCode;
}

/// Indian financial year string for a given date: "25-26" means Apr 2025 → Mar 2026.
export function financialYearForDate(d: Date): string {
  const m = d.getMonth(); // 0–11
  const y = d.getFullYear();
  const start = m >= 3 ? y : y - 1; // Apr (m=3) starts the FY
  const end = start + 1;
  return `${String(start % 100).padStart(2, '0')}-${String(end % 100).padStart(2, '0')}`;
}

import 'dotenv/config';
import bcrypt from 'bcrypt';
import crypto from 'crypto';
import prisma from '../infra/db/prisma.js';
import { productsService } from '../modules/products/products.service.js';
import { partiesService } from '../modules/parties/parties.service.js';
import { vendorsService } from '../modules/vendors/vendors.service.js';
import { invoicesService } from '../modules/invoices/invoices.service.js';
import { paymentsService } from '../modules/payments/payments.service.js';
import { stockService } from '../modules/stock/stock.service.js';
import { quotationsService } from '../modules/quotations/quotations.service.js';
import { challansService } from '../modules/challans/challans.service.js';
import { couponsService } from '../modules/coupons/coupons.service.js';
import { bannersService } from '../modules/banners/banners.service.js';
import { customFieldsService } from '../modules/customFields/customFields.service.js';
import { purchaseRequestsService } from '../modules/purchase-requests/purchase-requests.service.js';
import { returnsService } from '../modules/returns/returns.service.js';
import { trendingService } from '../modules/trending/trending.service.js';
import { seedDefaultRoles } from '../modules/team/team.service.js';
import { presetFor } from '../shared/http/permissions.js';
import { recomputeDay } from '../modules/analytics-rollup/aggregates.recompute.js';
import { istDateUTC } from '../shared/time/ist.js';

const MERCHANT_EMAIL = 'nkumawat1010@gmail.com';
const MERCHANT_PASSWORD = 'N8956827389';
const MERCHANT_NAME = 'Nikhil Kumawat';
const SHOP_NAME = 'Kumawat Electronics & Traders';

const CUSTOMER_EMAIL = 'grahak.kumawat1010@gmail.com';
const CUSTOMER_PASSWORD = 'N8956827389';
const CUSTOMER_NAME = 'Rohit Sharma';

const HISTORY_DAYS = 75;

const ux = (id: string): string =>
  `https://images.unsplash.com/${id}?w=900&h=900&fit=crop&auto=format&q=70`;

function daysAgo(n: number, hour = 12, min = 0): Date {
  const d = new Date();
  d.setDate(d.getDate() - n);
  d.setHours(hour, min, 0, 0);
  return d;
}
const randInt = (lo: number, hi: number) => lo + Math.floor(Math.random() * (hi - lo + 1));
const pick = <T,>(arr: T[]): T => arr[Math.floor(Math.random() * arr.length)];

const touchedDays = new Set<number>();
function touch(d: Date): void {
  touchedDays.add(istDateUTC(d).getTime());
}

let failures = 0;
async function step<T>(label: string, fn: () => Promise<T>): Promise<T | null> {
  try {
    const out = await fn();
    console.log(`  ✓ ${label}`);
    return out;
  } catch (err) {
    failures += 1;
    console.error(`  ✗ ${label}\n      ${(err as Error)?.message ?? err}`);
    return null;
  }
}

function slugify(input: string): string {
  return input.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
}
async function uniqueShopSlug(base: string): Promise<string> {
  let candidate = base || 'shop';
  let n = 1;
  for (;;) {
    const hit = await prisma.shop.findUnique({ where: { slug: candidate }, select: { id: true } });
    if (!hit) return candidate;
    n += 1;
    candidate = `${base}-${n}`;
  }
}

async function ensureMerchant(): Promise<{ userId: number; shopId: number }> {
  const existing = await prisma.user.findUnique({
    where: { email: MERCHANT_EMAIL },
    select: { id: true, role: true },
  });
  if (existing) {
    if (existing.role !== 'OWNER') {
      throw new Error(`${MERCHANT_EMAIL} exists with role ${existing.role}; delete it or reset the DB.`);
    }
    let shop = await prisma.shop.findUnique({ where: { ownerUserId: existing.id }, select: { id: true } });
    if (!shop) {
      const slug = await uniqueShopSlug(slugify(SHOP_NAME));
      shop = await prisma.shop.create({
        data: { ownerUserId: existing.id, name: SHOP_NAME, slug, isPublished: true },
        select: { id: true },
      });
      await prisma.shopMember.upsert({
        where: { userId: existing.id },
        create: { shopId: shop.id, userId: existing.id, role: 'OWNER' },
        update: { shopId: shop.id, role: 'OWNER' },
      });
    } else {
      await prisma.shop.update({ where: { id: shop.id }, data: { isPublished: true, vacationMode: false } });
    }
    return { userId: existing.id, shopId: shop.id };
  }

  const passwordHash = await bcrypt.hash(MERCHANT_PASSWORD, 12);
  const slug = await uniqueShopSlug(slugify(SHOP_NAME));
  return prisma.$transaction(async (tx) => {
    const u = await tx.user.create({
      data: {
        email: MERCHANT_EMAIL,
        name: MERCHANT_NAME,
        passwordHash,
        role: 'OWNER',
        shopName: SHOP_NAME,
        acceptedAt: new Date(),
      },
      select: { id: true },
    });
    const s = await tx.shop.create({
      data: { ownerUserId: u.id, name: SHOP_NAME, slug, isPublished: true },
      select: { id: true },
    });
    await tx.shopMember.create({ data: { shopId: s.id, userId: u.id, role: 'OWNER' } });
    return { userId: u.id, shopId: s.id };
  });
}

async function ensureCustomer(): Promise<{ userId: number; addressId: number }> {
  let user = await prisma.user.findUnique({ where: { email: CUSTOMER_EMAIL }, select: { id: true } });
  if (!user) {
    const passwordHash = await bcrypt.hash(CUSTOMER_PASSWORD, 12);
    user = await prisma.user.create({
      data: {
        email: CUSTOMER_EMAIL,
        name: CUSTOMER_NAME,
        passwordHash,
        role: 'CUSTOMER',
        acceptedAt: new Date(),
      },
      select: { id: true },
    });
  }
  let address = await prisma.userAddress.findFirst({ where: { userId: user.id }, select: { id: true } });
  if (!address) {
    address = await prisma.userAddress.create({
      data: {
        userId: user.id,
        label: 'Home',
        fullName: CUSTOMER_NAME,
        phone: '9876500011',
        line1: '14 Rajwada Road',
        line2: 'Near Clock Tower',
        city: 'Jaipur',
        state: 'Rajasthan',
        pincode: '302001',
        isDefault: true,
      },
      select: { id: true },
    });
  }
  return { userId: user.id, addressId: address.id };
}

async function categoryIdBySlug(slug: string): Promise<number | undefined> {
  const row = await prisma.category.findUnique({ where: { slug }, select: { id: true } });
  return row?.id;
}

type SeedProduct = Parameters<typeof productsService.createProduct>[0] & { categorySlug?: string };

const PRODUCTS: SeedProduct[] = [
  {
    name: 'Aether X12 Pro 5G',
    description:
      'Pro-grade 5G flagship with a 6.78" LTPO AMOLED, triple 50MP camera system with OIS, titanium frame and 120W SuperVOOC charging that tops up in 19 minutes.',
    sku: 'AETHER-X12P', barcode: '8901234500011', hsnCode: '85171300', brand: 'Aether',
    countryOfOrigin: 'India',
    mrp: 79999, sellingPrice: 64999, purchasePrice: 51000, taxPercent: 18, cessRate: 0,
    stockQuantity: 0, lowStockThreshold: 10, unit: 'PCS', categorySlug: 'smartphones',
    tags: ['5G', 'AMOLED', 'flagship', 'OIS'],
    imageUrls: [ux('photo-1610945265064-0e34e5519bbf'), ux('photo-1592286927505-1def25115558'), ux('photo-1511707171634-5f897ff02aa9')],
    highlights: ['6.78" LTPO AMOLED · 120Hz', 'Snapdragon 8 Gen 3 · 12GB', 'Triple 50MP OIS camera', '120W SuperVOOC · 5400mAh'],
    specs: [
      { title: 'Display', tab: 'General', rows: [{ label: 'Size', value: '6.78 inch' }, { label: 'Type', value: 'LTPO AMOLED 120Hz' }, { label: 'Peak brightness', value: '4500 nits' }] },
      { title: 'Performance', tab: 'General', rows: [{ label: 'Chipset', value: 'Snapdragon 8 Gen 3' }, { label: 'RAM', value: '12 GB LPDDR5X' }] },
      { title: 'Warranty', tab: 'Warranty', rows: [{ label: 'Warranty', value: '1 year manufacturer' }, { label: 'Launch', value: '2026' }] },
    ],
    offers: [
      { kind: 'BANK', headline: '10% off on HDFC Credit Cards', detail: 'Up to ₹3,000 on orders above ₹20,000.' },
      { kind: 'EXCHANGE', headline: 'Up to ₹18,000 off with exchange' },
    ],
    variantAxes: [{ name: 'Storage', values: ['256GB', '512GB'] }],
    variants: [
      { sku: 'AETHER-X12P-256', barcode: '8901234500021', attributes: { Storage: '256GB' }, mrp: 79999, sellingPrice: 64999, purchasePrice: 51000, stockQuantity: 0, imageUrls: [ux('photo-1610945265064-0e34e5519bbf')] },
      { sku: 'AETHER-X12P-512', barcode: '8901234500022', attributes: { Storage: '512GB' }, mrp: 86999, sellingPrice: 70999, purchasePrice: 55500, stockQuantity: 0, imageUrls: [ux('photo-1592286927505-1def25115558')] },
    ],
  },
  {
    name: 'PulseAir Pods Pro (2nd Gen)',
    description:
      'True wireless earbuds with adaptive ANC up to 42dB, personalised spatial audio with head tracking, and 32-hour total playback with the wireless charging case.',
    sku: 'PULSE-PODSPRO2', barcode: '8902345600011', hsnCode: '85183000', brand: 'PulseAir',
    countryOfOrigin: 'China',
    mrp: 12999, sellingPrice: 8999, purchasePrice: 5400, taxPercent: 18,
    stockQuantity: 0, lowStockThreshold: 25, unit: 'PCS', categorySlug: 'earbuds',
    tags: ['ANC', 'true-wireless', 'spatial-audio'],
    imageUrls: [ux('photo-1590658268037-6bf12165a8df'), ux('photo-1606220945770-b5b6c2c55bf1')],
    highlights: ['Adaptive ANC up to 42dB', 'Spatial audio + head tracking', '32h total with case', 'IPX4 sweat resistant'],
    specs: [
      { title: 'Audio', tab: 'General', rows: [{ label: 'Driver', value: '11mm dynamic' }, { label: 'Codec', value: 'AAC, LDAC' }] },
      { title: 'Battery', tab: 'General', rows: [{ label: 'Buds', value: '8 hours' }, { label: 'With case', value: '32 hours' }] },
    ],
    offers: [{ kind: 'COUPON', headline: 'Buy 2 save ₹1500', code: 'PAIRUP' }],
  },
  {
    name: 'Nimbus Vortex 14 OLED',
    description:
      '14" 3K OLED creator ultrabook — Core Ultra 9, RTX 4060, 32GB LPDDR5X and a 1TB Gen4 SSD in a 1.49 kg CNC-aluminium chassis.',
    sku: 'NIMBUS-V14', barcode: '8903456700011', hsnCode: '84713010', brand: 'Nimbus',
    countryOfOrigin: 'China',
    mrp: 159999, sellingPrice: 134999, purchasePrice: 108000, taxPercent: 18,
    stockQuantity: 0, lowStockThreshold: 5, unit: 'PCS', categorySlug: 'laptops',
    tags: ['OLED', 'creator', 'RTX', 'thin-light'],
    imageUrls: [ux('photo-1517336714731-489689fd1ca8'), ux('photo-1496181133206-80ce9b88a853')],
    highlights: ['14" 3K OLED · 120Hz', 'Core Ultra 9 · RTX 4060', '32GB LPDDR5X · 1TB SSD', '1.49 kg · 75Wh'],
    specs: [
      { title: 'Display', tab: 'General', rows: [{ label: 'Panel', value: '14" 3K OLED' }, { label: 'Refresh', value: '120Hz' }] },
      { title: 'Graphics', tab: 'General', rows: [{ label: 'GPU', value: 'NVIDIA RTX 4060 8GB' }] },
    ],
    offers: [{ kind: 'EMI', headline: 'No-cost EMI up to 12 months' }],
  },
  {
    name: 'ChronoFit S3 AMOLED',
    description:
      'Smartwatch with a 1.43" always-on AMOLED, dual-frequency GPS, SpO2 + heart-rate, 5ATM water resistance and up to 14-day battery.',
    sku: 'CHRONO-S3', barcode: '8904567800011', hsnCode: '91029900', brand: 'ChronoFit',
    countryOfOrigin: 'India',
    mrp: 9999, sellingPrice: 6499, purchasePrice: 3800, taxPercent: 18,
    stockQuantity: 0, lowStockThreshold: 20, unit: 'PCS', categorySlug: 'smartwatches',
    tags: ['fitness', 'GPS', 'AMOLED'],
    imageUrls: [ux('photo-1523275335684-37898b6baf30'), ux('photo-1579586337278-3befd40fd17a')],
    highlights: ['1.43" AMOLED always-on', 'Dual-frequency GPS', '5ATM · 120+ sport modes', '14-day battery'],
    specs: [{ title: 'Health', tab: 'General', rows: [{ label: 'Sensors', value: 'HR, SpO2, skin temp' }, { label: 'Water', value: '5ATM' }] }],
  },
  {
    name: 'BassRock Cube Mini',
    description:
      'Pocketable Bluetooth speaker with 360° sound, dual passive radiators, 18-hour playback, IPX7 waterproofing and TWS stereo pairing.',
    sku: 'BASS-CUBEMINI', barcode: '8905678900011', hsnCode: '85182900', brand: 'BassRock',
    countryOfOrigin: 'China',
    mrp: 4999, sellingPrice: 3299, purchasePrice: 1800, taxPercent: 18,
    stockQuantity: 0, lowStockThreshold: 30, unit: 'PCS', categorySlug: 'bluetooth-speakers',
    tags: ['portable', 'IPX7', 'TWS'],
    imageUrls: [ux('photo-1608043152269-423dbba4e7e1'), ux('photo-1589003077984-894e133dabab')],
    highlights: ['360° sound', '18h playback', 'IPX7 waterproof', 'TWS stereo pair'],
    specs: [{ title: 'Audio', tab: 'General', rows: [{ label: 'Output', value: '10W RMS' }, { label: 'Drivers', value: '1 + 2 passive radiators' }] }],
    offers: [{ kind: 'COUPON', headline: '₹400 off with SOUNDON', code: 'SOUNDON' }],
  },
  {
    name: 'VoltStash 20K MagFlow',
    description:
      'Slim 20,000mAh power bank with 100W USB-C PD output, 15W magnetic wireless pad, and a live-charge LED readout. Airline-safe.',
    sku: 'VOLT-20K', barcode: '8908901200011', hsnCode: '85076000', brand: 'VoltStash',
    countryOfOrigin: 'India',
    mrp: 5999, sellingPrice: 3999, purchasePrice: 2200, taxPercent: 18,
    stockQuantity: 0, lowStockThreshold: 40, unit: 'PCS', categorySlug: 'power-banks',
    tags: ['fast-charge', 'PD', 'magnetic'],
    imageUrls: [ux('photo-1609091839311-d5365f9ff1c5'), ux('photo-1583863788434-e58a36330cf0')],
    highlights: ['20,000mAh', '100W USB-C PD', '15W magnetic wireless', 'Airline-safe'],
    specs: [{ title: 'Charging', tab: 'General', rows: [{ label: 'Max output', value: '100W' }, { label: 'Ports', value: '2× USB-C, 1× USB-A' }] }],
  },
  {
    name: 'ClickForge K7 Mechanical',
    description:
      'Hot-swappable 75% mechanical keyboard — gasket mount, PBT double-shot keycaps, south-facing RGB and tri-mode (BT/2.4G/USB-C) connectivity.',
    sku: 'CLICK-K7', barcode: '8909012300011', hsnCode: '84716060', brand: 'ClickForge',
    countryOfOrigin: 'China',
    mrp: 8499, sellingPrice: 5799, purchasePrice: 3200, taxPercent: 18,
    stockQuantity: 0, lowStockThreshold: 15, unit: 'PCS', categorySlug: 'keyboards',
    tags: ['mechanical', 'hot-swap', 'RGB'],
    imageUrls: [ux('photo-1587829741301-dc798b83add3'), ux('photo-1618384887929-16ec33fab9ef')],
    highlights: ['75% gasket-mount', 'Hot-swap switches', 'PBT double-shot caps', 'Tri-mode BT/2.4G/USB-C'],
    specs: [{ title: 'Build', tab: 'General', rows: [{ label: 'Layout', value: '75% (82 keys)' }, { label: 'Switches', value: 'Linear pre-lubed' }] }],
  },
  {
    name: 'VisionArc 27 4K USB-C',
    description:
      '27" 4K UHD IPS monitor with 99% sRGB, 65W USB-C power delivery, height-adjustable stand and factory colour calibration for creators.',
    sku: 'VISION-27UC', barcode: '8900123400011', hsnCode: '85285200', brand: 'VisionArc',
    countryOfOrigin: 'China',
    mrp: 32999, sellingPrice: 24999, purchasePrice: 18500, taxPercent: 18,
    stockQuantity: 0, lowStockThreshold: 8, unit: 'PCS', categorySlug: 'monitors',
    tags: ['4K', 'USB-C', 'IPS', 'creator'],
    imageUrls: [ux('photo-1527443224154-c4a3942d3acf'), ux('photo-1547119957-637f8679db1e')],
    highlights: ['27" 4K UHD IPS', '99% sRGB · factory calibrated', '65W USB-C PD', 'Ergo height/tilt/pivot'],
    specs: [{ title: 'Panel', tab: 'General', rows: [{ label: 'Resolution', value: '3840×2160' }, { label: 'Refresh', value: '60Hz' }] }],
    offers: [{ kind: 'EMI', headline: 'No-cost EMI up to 9 months' }],
  },
  {
    name: 'AuraBeats Studio Over-Ear',
    description:
      'Over-ear wireless headphones with hybrid ANC, 40mm graphene drivers, Hi-Res LDAC, plush memory-foam cushions and 60-hour battery.',
    sku: 'AURA-STUDIO', barcode: '8900234500011', hsnCode: '85183000', brand: 'AuraBeats',
    countryOfOrigin: 'China',
    mrp: 14999, sellingPrice: 9999, purchasePrice: 6100, taxPercent: 18,
    stockQuantity: 0, lowStockThreshold: 18, unit: 'PCS', categorySlug: 'headphones',
    tags: ['ANC', 'over-ear', 'Hi-Res'],
    imageUrls: [ux('photo-1505740420928-5e560c06d30e'), ux('photo-1583394838336-acd977736f90')],
    highlights: ['Hybrid ANC', '40mm graphene drivers', 'Hi-Res LDAC', '60h battery · fast charge'],
    specs: [{ title: 'Audio', tab: 'General', rows: [{ label: 'Drivers', value: '40mm graphene' }, { label: 'Codec', value: 'LDAC, AAC, SBC' }] }],
  },
  {
    name: 'SlateTab Ultra 12.4',
    description:
      '12.4" 2.5K 120Hz tablet with an octa-core chip, 10,090mAh battery, quad AKG speakers and stylus support — bundled folio keyboard optional.',
    sku: 'SLATE-U124', barcode: '8900345600011', hsnCode: '84713090', brand: 'SlateTab',
    countryOfOrigin: 'China',
    mrp: 44999, sellingPrice: 33999, purchasePrice: 25000, taxPercent: 18,
    stockQuantity: 0, lowStockThreshold: 10, unit: 'PCS', categorySlug: 'tablets',
    tags: ['tablet', '120Hz', 'stylus'],
    imageUrls: [ux('photo-1544244015-0df4b3ffc6b0'), ux('photo-1561154464-82e9adf32764')],
    highlights: ['12.4" 2.5K 120Hz', 'Octa-core · 8GB', '10,090mAh · quad AKG', 'Stylus + folio support'],
    specs: [{ title: 'Display', tab: 'General', rows: [{ label: 'Size', value: '12.4 inch' }, { label: 'Resolution', value: '2560×1600' }] }],
    variantAxes: [{ name: 'Storage', values: ['128GB', '256GB'] }],
    variants: [
      { sku: 'SLATE-U124-128', attributes: { Storage: '128GB' }, mrp: 44999, sellingPrice: 33999, purchasePrice: 25000, stockQuantity: 0, imageUrls: [ux('photo-1544244015-0df4b3ffc6b0')] },
      { sku: 'SLATE-U124-256', attributes: { Storage: '256GB' }, mrp: 49999, sellingPrice: 37999, purchasePrice: 28000, stockQuantity: 0, imageUrls: [ux('photo-1561154464-82e9adf32764')] },
    ],
  },
];

async function seedProducts(shopId: number): Promise<number[]> {
  const ids: number[] = [];
  for (const seed of PRODUCTS) {
    const { categorySlug, imageUrls, highlights, specs, offers, tags, brand } = seed;
    const categoryId = categorySlug ? await categoryIdBySlug(categorySlug) : undefined;
    const exists = await prisma.product.findUnique({
      where: { shopId_sku: { shopId, sku: seed.sku } },
      select: { id: true, images: { select: { id: true } } },
    });
    if (exists) {
      if (exists.images.length === 0 && imageUrls?.length) {
        await prisma.productImage.createMany({
          data: imageUrls.map((url, i) => ({ productId: exists.id, url, sortOrder: i })),
        });
      }
      await productsService.updateProduct(shopId, exists.id, {
        highlights, specs, offers, tags, brand, categoryId,
      });
      await productsService.setPublished(shopId, exists.id, true);
      ids.push(exists.id);
      continue;
    }
    const { categorySlug: _drop, ...rest } = seed;
    const product = await productsService.createProduct({ ...rest, categoryId }, { shopId });
    await productsService.setPublished(shopId, product.id, true);
    const fakeSold = 80 + randInt(0, 400);
    await prisma.product.update({
      where: { id: product.id },
      data: { soldLast30d: fakeSold, totalSold: fakeSold * 3 },
    });
    ids.push(product.id);
  }
  return ids;
}

async function main(): Promise<void> {
  console.log(`\n▶ Full-feature seed for ${MERCHANT_EMAIL}\n`);

  const { userId, shopId } = await ensureMerchant();
  console.log(`  ✓ merchant userId=${userId} shopId=${shopId}`);
  const customer = await ensureCustomer();
  console.log(`  ✓ customer userId=${customer.userId} addressId=${customer.addressId}`);

  const productIds = (await step('Products (10 · full detail · images · variants)', () => seedProducts(shopId))) ?? [];
  const products = await prisma.product.findMany({
    where: { id: { in: productIds } },
    select: { id: true, name: true, sku: true, sellingPrice: true, purchasePrice: true, taxPercent: true },
  });
  const byId = new Map(products.map((p) => [p.id, p]));
  const prod = (i: number) => {
    const p = byId.get(productIds[i]);
    if (!p) throw new Error(`product ${i} missing`);
    return p;
  };

  let linkedPartyId = 0;
  const partyIds: number[] = [];
  await step('Parties (customers) + link one to the buyer', async () => {
    const defs = [
      { name: 'Sharma Electronics', contactName: 'Rohit Sharma', phone: '9876500011', email: CUSTOMER_EMAIL, city: 'Jaipur', state: 'Rajasthan', stateCode: '08', gstin: '08ABCDE1234F1Z5' },
      { name: 'Gupta Retail', contactName: 'Anita Gupta', phone: '9876500022', city: 'Delhi', state: 'Delhi', stateCode: '07', gstin: '07PQRSX6789K1Z2' },
      { name: 'Verma Mobile World', contactName: 'Sunil Verma', phone: '9876500044', city: 'Jaipur', state: 'Rajasthan', stateCode: '08' },
      { name: 'Bansal Digital Hub', contactName: 'Pooja Bansal', phone: '9876500055', city: 'Kota', state: 'Rajasthan', stateCode: '08' },
      { name: 'Iqbal Traders', contactName: 'Imran Iqbal', phone: '9876500066', city: 'Ajmer', state: 'Rajasthan', stateCode: '08' },
      { name: 'Walk-in / Cash', contactName: '', phone: '9876500033', city: 'Jaipur', state: 'Rajasthan', stateCode: '08' },
    ];
    for (const d of defs) {
      const exists = await prisma.party.findFirst({ where: { shopId, name: d.name }, select: { id: true } });
      const party = exists ?? (await partiesService.createParty(shopId, d));
      partyIds.push(party.id);
      if (d.email === CUSTOMER_EMAIL) {
        linkedPartyId = party.id;
        await prisma.party.update({ where: { id: party.id }, data: { linkedUserId: customer.userId } });
      }
    }
  });

  const vendorIds: number[] = [];
  await step('Vendors (suppliers)', async () => {
    const defs = [
      { name: 'Aether India Distributors', contactName: 'Vikram Rao', phone: '9811000011', city: 'Mumbai', state: 'Maharashtra', stateCode: '27', gstin: '27AAAAA0000A1Z5' },
      { name: 'PulseAir Wholesale', contactName: 'Sana Khan', phone: '9811000022', city: 'Bengaluru', state: 'Karnataka', stateCode: '29', gstin: '29BBBBB1111B1Z6' },
      { name: 'Northlight Imports', contactName: 'Deepak Nair', phone: '9811000033', city: 'Delhi', state: 'Delhi', stateCode: '07' },
      { name: 'Zenith Components Co.', contactName: 'Farah Sheikh', phone: '9811000044', city: 'Ahmedabad', state: 'Gujarat', stateCode: '24' },
    ];
    for (const d of defs) {
      const exists = await prisma.vendor.findFirst({ where: { shopId, name: d.name }, select: { id: true } });
      const v = exists ?? (await vendorsService.createVendor(shopId, d));
      vendorIds.push(v.id);
    }
  });
  const vendorId = vendorIds[0] ?? 0;

  await step('Opening stock (backdated bulk purchases → stock in)', async () => {
    const existing = await prisma.invoice.count({ where: { shopId, type: 'PURCHASE' } });
    if (existing >= 3) return;
    const openDate = daysAgo(HISTORY_DAYS, 10);
    const groups: number[][] = [[0, 1, 2], [3, 4], [5, 6], [7, 8, 9]];
    for (let g = 0; g < groups.length; g++) {
      const items = groups[g].map((i) => {
        const p = prod(i);
        return { productId: p.id, quantity: 800, unitPrice: Number(p.purchasePrice) };
      });
      const d = daysAgo(HISTORY_DAYS - g, 10, g * 5);
      const res = await invoicesService.createInvoice({
        shopId, type: 'PURCHASE', vendorId: vendorIds[g % vendorIds.length],
        invoiceDate: d.toISOString(), note: 'Opening stock purchase',
        items, confirm: true, confirmedById: userId,
      });
      if ('error' in res) throw new Error(`opening purchase: ${res.error}`);
      touch(d);
    }
    void openDate;
  });

  await step('Restock purchases (spread across the window)', async () => {
    const existing = await prisma.invoice.count({ where: { shopId, type: 'PURCHASE', note: 'Restock' } });
    if (existing > 0) return;
    for (const day of [55, 40, 26, 12]) {
      const n = randInt(2, 3);
      const idxs = Array.from({ length: n }, () => randInt(0, PRODUCTS.length - 1));
      const items = [...new Set(idxs)].map((i) => {
        const p = prod(i);
        return { productId: p.id, quantity: randInt(50, 150), unitPrice: Number(p.purchasePrice) };
      });
      const d = daysAgo(day, 11, randInt(0, 50));
      const res = await invoicesService.createInvoice({
        shopId, type: 'PURCHASE', vendorId: pick(vendorIds),
        invoiceDate: d.toISOString(), note: 'Restock', items, confirm: true, confirmedById: userId,
      });
      if ('error' in res) throw new Error(`restock: ${res.error}`);
      touch(d);
    }
  });

  const saleInvoiceIds: number[] = [];
  await step('Historical sales (backdated → sales graph + receivables)', async () => {
    const tagged = await prisma.invoice.count({ where: { shopId, type: 'SALE', note: 'SEED-HIST' } });
    if (tagged >= 40) {
      const rows = await prisma.invoice.findMany({ where: { shopId, type: 'SALE' }, select: { id: true }, orderBy: { id: 'desc' }, take: 5 });
      saleInvoiceIds.push(...rows.map((r) => r.id));
      return;
    }
    const saleParties = partyIds.filter((id) => id !== 0);
    for (let day = HISTORY_DAYS - 2; day >= 0; day--) {
      const trend = 1 - day / HISTORY_DAYS;
      if (Math.random() > 0.55 + trend * 0.3) continue;
      const invoicesToday = 1 + (Math.random() < 0.35 + trend * 0.4 ? 1 : 0) + (Math.random() < trend * 0.3 ? 1 : 0);
      for (let k = 0; k < invoicesToday; k++) {
        const lineCount = randInt(1, 3);
        const chosen = [...new Set(Array.from({ length: lineCount }, () => randInt(0, PRODUCTS.length - 1)))];
        const items = chosen.map((i) => {
          const p = prod(i);
          return { productId: p.id, quantity: randInt(1, 3), unitPrice: Number(p.sellingPrice) };
        });
        const d = daysAgo(day, randInt(9, 20), randInt(0, 59));
        const discount = Math.random() < 0.25 ? randInt(200, 1500) : 0;
        const res = await invoicesService.createInvoice({
          shopId, type: 'SALE', partyId: pick(saleParties),
          invoiceDate: d.toISOString(), discount, note: 'SEED-HIST',
          items, confirm: true, confirmedById: userId,
        });
        if ('error' in res) {
          if (String((res as { error: string }).error).includes('STOCK')) continue;
          throw new Error(`sale @day-${day}: ${(res as { error: string }).error}`);
        }
        saleInvoiceIds.push(res.invoice.id);
        touch(d);
      }
    }
  });

  await step('Draft sales invoices', async () => {
    const drafts = await prisma.invoice.count({ where: { shopId, type: 'SALE', status: 'DRAFT' } });
    if (drafts >= 2) return;
    for (const day of [4, 1]) {
      const p = prod(randInt(0, PRODUCTS.length - 1));
      const d = daysAgo(day, 15);
      await invoicesService.createInvoice({
        shopId, type: 'SALE', partyId: pick(partyIds.filter((id) => id !== 0)),
        invoiceDate: d.toISOString(), items: [{ productId: p.id, quantity: 1, unitPrice: Number(p.sellingPrice) }],
        confirm: false,
      });
    }
  });

  await step('Payments (receipts + vendor payments → ledger + cash graph)', async () => {
    const existing = await prisma.payment.count({ where: { shopId } });
    if (existing >= 25) return;
    const sales = await prisma.invoice.findMany({
      where: { shopId, type: 'SALE', status: 'CONFIRMED' },
      select: { id: true, partyId: true, total: true, invoiceDate: true },
      orderBy: { invoiceDate: 'asc' },
    });
    for (const s of sales) {
      if (!s.partyId || Math.random() > 0.55) continue;
      const total = Number(s.total);
      const amount = Math.random() < 0.6 ? total : Math.round(total * (0.3 + Math.random() * 0.4));
      const d = new Date(s.invoiceDate.getTime() + randInt(0, 3) * 864e5);
      if (d.getTime() > Date.now()) d.setTime(Date.now());
      await paymentsService.createPayment({
        shopId, type: 'RECEIPT', amount, mode: pick(['UPI', 'CASH', 'NEFT', 'CARD'] as const),
        partyId: s.partyId, invoiceId: s.id, paymentDate: d, createdById: userId,
        note: amount >= total ? 'Full payment' : 'Part payment',
      });
      touch(d);
    }
    for (const day of [60, 44, 30, 15, 5]) {
      const d = daysAgo(day, 16, randInt(0, 59));
      await paymentsService.createPayment({
        shopId, type: 'PAYMENT', amount: randInt(15000, 60000), mode: pick(['NEFT', 'RTGS', 'UPI'] as const),
        vendorId: pick(vendorIds), paymentDate: d, createdById: userId, note: 'Vendor settlement',
      });
      touch(d);
    }
  });

  await step('Stock transactions (manual in/out)', async () => {
    const count = await prisma.stockTransaction.count({ where: { shopId, sourceType: 'MANUAL' } });
    if (count > 0) return;
    const inRes = await stockService.createTransaction(shopId, { productId: prod(3).id, type: 'STOCK_IN', quantity: 25, vendorId, note: 'Counted extra units', createdById: userId } as never);
    if (inRes && typeof inRes === 'object' && 'error' in inRes) throw new Error(`stock in: ${(inRes as { error: string }).error}`);
    const outRes = await stockService.createTransaction(shopId, { productId: prod(5).id, type: 'STOCK_OUT', quantity: 3, partyId: linkedPartyId, note: 'Damaged units', createdById: userId } as never);
    if (outRes && typeof outRes === 'object' && 'error' in outRes) throw new Error(`stock out: ${(outRes as { error: string }).error}`);
  });

  await step('Quotations (to linked customer)', async () => {
    const count = await prisma.quotation.count({ where: { shopId } });
    if (count >= 4) return;
    const combos = [
      [1, 4, 5],
      [2, 7],
      [0, 3],
      [8, 9, 6],
    ];
    for (const combo of combos) {
      const items = combo.map((i) => {
        const p = prod(i);
        return { productId: p.id, name: p.name, sku: p.sku, quantity: randInt(1, 6), unitPrice: Number(p.sellingPrice) };
      });
      const res = await quotationsService.create(shopId, linkedPartyId, userId, {
        items, note: 'Bulk order quote — valid 15 days',
      });
      if ('error' in res) throw new Error(`quotation: ${res.error}`);
    }
  });

  await step('Delivery challans', async () => {
    const count = await prisma.challan.count({ where: { shopId } });
    if (count >= 3) return;
    const combos: Array<{ party: number; items: number[] }> = [
      { party: linkedPartyId, items: [4] },
      { party: partyIds[1] ?? linkedPartyId, items: [5, 6] },
      { party: partyIds[2] ?? linkedPartyId, items: [3] },
    ];
    for (const c of combos) {
      const res = await challansService.createChallan(shopId, {
        partyId: c.party,
        items: c.items.map((i) => ({ productId: prod(i).id, quantity: randInt(2, 8) })),
        note: 'Goods on approval',
        createdById: userId,
      });
      if ('error' in res) throw new Error(`challan: ${res.error}`);
    }
  });

  await step('Coupons', async () => {
    const now = new Date();
    const in30 = new Date(now.getTime() + 30 * 864e5);
    for (const c of [
      { code: 'WELCOME10', title: 'Welcome 10% off', discountType: 'PERCENT' as const, discountValue: 10, maxDiscount: 2000, minOrderAmount: 1000, isPublic: true },
      { code: 'FLAT500', title: 'Flat ₹500 off over ₹5000', discountType: 'FLAT' as const, discountValue: 500, minOrderAmount: 5000, isPublic: true },
      { code: 'AUDIO15', title: '15% off audio', discountType: 'PERCENT' as const, discountValue: 15, maxDiscount: 1500, minOrderAmount: 2000, isPublic: true },
    ]) {
      const exists = await prisma.coupon.findFirst({ where: { shopId, code: c.code }, select: { id: true } });
      if (exists) continue;
      const res = await couponsService.createForShop(shopId, { ...c, validFrom: now, validUntil: in30 });
      if ('error' in res) throw new Error(`coupon ${c.code}: ${res.error}`);
    }
  });

  await step('Banners (hero + ad-strip)', async () => {
    const count = await prisma.banner.count({ where: { shopId } });
    if (count > 0) return;
    await bannersService.createForShop(shopId, { placement: 'HERO', imageUrl: ux('photo-1607082349566-187342175e2f'), linkUrl: '/shop', sortOrder: 0, isActive: true });
    await bannersService.createForShop(shopId, { placement: 'HERO', imageUrl: ux('photo-1550009158-9ebf69173e03'), linkUrl: '/shop', sortOrder: 1, isActive: true });
    await bannersService.createForShop(shopId, { placement: 'AD_STRIP', imageUrl: ux('photo-1526170375885-4d8ecf77b99f'), linkUrl: '/shop', sortOrder: 0, isActive: true });
  });

  await step('Custom fields (section + definitions)', async () => {
    const count = await prisma.customFieldDefinition.count({ where: { shopId } });
    if (count > 0) return;
    const section = await customFieldsService.createSection(shopId, { name: 'Warranty & Support', sortOrder: 0 });
    for (const d of [
      { name: 'Warranty period', type: 'TEXT' as const, sectionId: section.id },
      { name: 'Serial number', type: 'TEXT' as const, sectionId: section.id },
      { name: 'Extended warranty', type: 'BOOLEAN' as const, sectionId: section.id },
      { name: 'Condition', type: 'DROPDOWN' as const, options: ['New', 'Refurbished', 'Open box'], sectionId: section.id },
    ]) {
      const res = await customFieldsService.createDefinition(shopId, d);
      if (res && typeof res === 'object' && 'error' in res) throw new Error(`custom field ${d.name}: ${res.error}`);
    }
  });

  let deliveredParentId = 0;
  let deliveredChildId = 0;
  await step('Customer orders (marketplace checkout · varied states)', async () => {
    const existing = await prisma.purchaseRequest.count({ where: { shopId } });
    if (existing >= 6) {
      const delivered = await prisma.purchaseRequest.findFirst({
        where: { shopId, status: 'CONFIRMED', events: { some: { type: 'DELIVERED' } } },
        select: { id: true, customerOrderId: true },
      });
      if (delivered) { deliveredChildId = delivered.id; deliveredParentId = delivered.customerOrderId; }
      return;
    }

    const place = async (items: Array<{ i: number; quantity: number }>, note: string) => {
      const res = await purchaseRequestsService.createForCustomer({
        customerUserId: customer.userId,
        addressId: customer.addressId,
        items: items.map((it) => ({ productId: prod(it.i).id, quantity: it.quantity })),
        note,
      });
      if ('error' in res) throw new Error(`order: ${res.error}`);
      return res.order;
    };
    const childFor = (order: { shopOrders: { id: number; shopId: number }[] }) =>
      order.shopOrders.find((c) => c.shopId === shopId)!;

    await place([{ i: 1, quantity: 2 }, { i: 5, quantity: 1 }], 'Please deliver on weekend');
    await place([{ i: 4, quantity: 3 }], 'Gift wrap if possible');

    for (const spec of [[{ i: 3, quantity: 1 }], [{ i: 6, quantity: 2 }, { i: 8, quantity: 1 }]]) {
      const order = await place(spec, 'Confirmed order');
      const child = childFor(order);
      const c = await purchaseRequestsService.confirmRequest({ shopId, requestId: child.id, decidedById: userId });
      if ('error' in c) throw new Error(`confirm: ${c.error}`);
    }

    {
      const order = await place([{ i: 7, quantity: 1 }], 'Shipped order');
      const child = childFor(order);
      const c = await purchaseRequestsService.confirmRequest({ shopId, requestId: child.id, decidedById: userId });
      if ('error' in c) throw new Error(`confirm(ship): ${c.error}`);
      for (const type of ['PACKED', 'SHIPPED', 'OUT_FOR_DELIVERY', 'DELIVERED'] as const) {
        await purchaseRequestsService.addShippingEvent({ shopId, requestId: child.id, actorId: userId, type, courier: 'BlueDart', awb: 'BD' + randInt(100000, 999999) });
      }
    }

    {
      const order = await place([{ i: 0, quantity: 1 }, { i: 4, quantity: 2 }], 'Return demo order');
      const child = childFor(order);
      const c = await purchaseRequestsService.confirmRequest({ shopId, requestId: child.id, decidedById: userId });
      if ('error' in c) throw new Error(`confirm(return): ${c.error}`);
      for (const type of ['PACKED', 'SHIPPED', 'DELIVERED'] as const) {
        await purchaseRequestsService.addShippingEvent({ shopId, requestId: child.id, actorId: userId, type, courier: 'Delhivery' });
      }
      deliveredChildId = child.id;
      deliveredParentId = order.id;
    }
  });

  await step('Returns (full workflow → REFUNDED credit note)', async () => {
    if (!deliveredChildId || !deliveredParentId) throw new Error('no delivered order to return');
    const existing = await prisma.returnRequest.count({ where: { shopId } });
    if (existing > 0) return;
    const item = await prisma.purchaseRequestItem.findFirst({
      where: { requestId: deliveredChildId },
      select: { id: true, quantity: true },
    });
    if (!item) throw new Error('delivered order has no items');
    const sub = await returnsService.submit({
      customerUserId: customer.userId,
      parentId: deliveredParentId,
      childId: deliveredChildId,
      note: 'One unit dead on arrival',
      items: [{ purchaseRequestItemId: item.id, quantity: 1, reason: 'DEFECTIVE' }],
    });
    if ('error' in sub) throw new Error(`return submit: ${sub.error}`);
    const rid = sub.id;
    const chain: Array<Promise<unknown>> = [];
    void chain;
    const a = await returnsService.approve({ shopId, id: rid, actorId: userId, note: 'Approved — send it back' });
    if ('error' in a) throw new Error(`approve: ${a.error}`);
    const pu = await returnsService.pickedUp({ shopId, id: rid, actorId: userId });
    if ('error' in pu) throw new Error(`pickedUp: ${pu.error}`);
    const rc = await returnsService.received({ shopId, id: rid, actorId: userId, note: 'Received at store' });
    if ('error' in rc) throw new Error(`received: ${rc.error}`);
    const rf = await returnsService.refund({ shopId, id: rid, actorId: userId, note: 'Refund to source' });
    if ('error' in rf) throw new Error(`refund: ${rf.error}`);
  });

  await step('Product reviews', async () => {
    const count = await prisma.productReview.count({ where: { product: { shopId } } });
    if (count >= 6) return;
    const reviews = [
      { i: 0, rating: 5, title: 'Superb flagship', body: 'Camera and battery are outstanding. Fast delivery.' },
      { i: 1, rating: 4, title: 'Great ANC', body: 'Noise cancellation is excellent for the price.' },
      { i: 2, rating: 5, title: 'Creator dream', body: 'The OLED is gorgeous and it stays cool under load.' },
      { i: 4, rating: 5, title: 'Loud & clear', body: 'Punchy bass, survived a pool party.' },
      { i: 6, rating: 4, title: 'Thocky and clean', body: 'Hot-swap sockets feel solid, typing is a joy.' },
      { i: 8, rating: 4, title: 'Warm sound', body: 'Comfortable for long sessions, ANC could be stronger.' },
    ];
    for (const r of reviews) {
      const p = prod(r.i);
      await prisma.productReview.upsert({
        where: { productId_userId: { productId: p.id, userId: customer.userId } },
        create: { productId: p.id, userId: customer.userId, rating: r.rating, title: r.title, body: r.body },
        update: { rating: r.rating, title: r.title, body: r.body },
      });
      const agg = await prisma.productReview.aggregate({ where: { productId: p.id }, _avg: { rating: true }, _count: true });
      await prisma.product.update({
        where: { id: p.id },
        data: { ratingAvg: agg._avg.rating ?? 0, ratingCount: agg._count },
      });
    }
  });

  await step('Custom-field values (per product)', async () => {
    const defs = await prisma.customFieldDefinition.findMany({
      where: { shopId }, select: { id: true, name: true, type: true },
    });
    if (defs.length === 0) return;
    const byName = new Map(defs.map((d) => [d.name, d]));
    const warranty = byName.get('Warranty period');
    const serial = byName.get('Serial number');
    const extended = byName.get('Extended warranty');
    const condition = byName.get('Condition');
    const conditions = ['New', 'Refurbished', 'Open box'];
    for (const p of products) {
      const pairs: Array<[{ id: number } | undefined, string]> = [
        [warranty, '1 year manufacturer'],
        [serial, `SN-${p.sku}-${String(1000 + (p.id % 9000))}`],
        [extended, p.id % 2 === 0 ? 'true' : 'false'],
        [condition, conditions[p.id % conditions.length]],
      ];
      for (const [def, value] of pairs) {
        if (!def) continue;
        await prisma.productCustomFieldValue.upsert({
          where: { productId_definitionId: { productId: p.id, definitionId: def.id } },
          create: { productId: p.id, definitionId: def.id, value },
          update: { value },
        });
      }
    }
  });

  let cashierUserId = 0;
  await step('Team members + pending invite', async () => {
    await seedDefaultRoles(prisma, shopId);
    const staff = [
      { email: 'priya.manager.kumawat@example.com', name: 'Priya Menon', role: 'MANAGER' as const, roleName: 'Manager' },
      { email: 'arjun.cashier.kumawat@example.com', name: 'Arjun Nair', role: 'CASHIER' as const, roleName: 'Cashier' },
    ];
    const passwordHash = await bcrypt.hash(MERCHANT_PASSWORD, 12);
    for (const s of staff) {
      let u = await prisma.user.findUnique({ where: { email: s.email }, select: { id: true } });
      if (!u) {
        u = await prisma.user.create({
          data: { email: s.email, name: s.name, passwordHash, role: 'OWNER', acceptedAt: new Date() },
          select: { id: true },
        });
      }
      await prisma.shopMember.upsert({
        where: { userId: u.id },
        create: { shopId, userId: u.id, role: s.role, roleName: s.roleName, permissions: presetFor(s.role) },
        update: { shopId, role: s.role, roleName: s.roleName, permissions: presetFor(s.role) },
      });
      if (s.role === 'CASHIER') cashierUserId = u.id;
    }
    const inviteEmail = 'newhire.kumawat@example.com';
    const existingInv = await prisma.invitation.findFirst({
      where: { shopId, toEmail: inviteEmail, linkType: 'TEAM', status: 'PENDING' }, select: { id: true },
    });
    if (!existingInv) {
      await prisma.invitation.create({
        data: {
          shopId, fromUserId: userId, toEmail: inviteEmail, linkType: 'TEAM',
          teamRole: 'STOCKIST', teamRoleName: 'Stockist', teamPermissions: presetFor('STOCKIST'),
          status: 'PENDING', fromShopName: SHOP_NAME, displayName: 'New Stockist',
          token: crypto.randomBytes(24).toString('hex'),
          expiresAt: new Date(Date.now() + 7 * 864e5),
        },
      });
    }
  });

  await step('Cashier shifts + cash movements', async () => {
    const opener = cashierUserId || userId;
    const haveMovements = await prisma.cashMovement.count({ where: { shopId } });
    if (haveMovements === 0) {
      const closed = await prisma.cashierShift.create({
        data: {
          shopId, openedById: opener, status: 'CLOSED',
          openingFloat: 2000, closingCounted: 15650, expectedCash: 15600, variance: 50,
          closingNote: 'Counted at end of day — ₹50 over.',
          openedAt: daysAgo(1, 9), closedAt: daysAgo(1, 21), closedById: opener,
        },
        select: { id: true },
      });
      await prisma.cashMovement.createMany({
        data: [
          { shopId, shiftId: closed.id, type: 'PAY_IN', amount: 500, reason: 'Float top-up', createdById: opener },
          { shopId, shiftId: closed.id, type: 'PAY_OUT', amount: 300, reason: 'Tea & snacks', createdById: opener },
          { shopId, shiftId: closed.id, type: 'DROP', amount: 5000, reason: 'Cash drop to safe', createdById: opener },
        ],
      });
    }
    const haveOpen = await prisma.cashierShift.count({ where: { shopId, status: 'OPEN' } });
    if (haveOpen === 0) {
      await prisma.cashierShift.create({
        data: { shopId, openedById: opener, status: 'OPEN', openingFloat: 2000, openedAt: daysAgo(0, 9) },
      });
    }
  });

  await step('Customer addresses (Work + Parents)', async () => {
    const count = await prisma.userAddress.count({ where: { userId: customer.userId } });
    if (count >= 3) return;
    await prisma.userAddress.createMany({
      data: [
        { userId: customer.userId, label: 'Work', fullName: CUSTOMER_NAME, phone: '9876500011', line1: 'Tech Park, Tower B', line2: 'Malviya Nagar', city: 'Jaipur', state: 'Rajasthan', pincode: '302017', isDefault: false },
        { userId: customer.userId, label: 'Parents', fullName: 'Suresh Sharma', phone: '9876500099', line1: '5 Civil Lines', city: 'Ajmer', state: 'Rajasthan', pincode: '305001', isDefault: false },
      ],
    });
  });

  await step('Customer wishlist', async () => {
    const count = await prisma.wishlistItem.count({ where: { userId: customer.userId } });
    if (count > 0) return;
    for (const i of [2, 7, 9, 5]) {
      await prisma.wishlistItem.upsert({
        where: { userId_productId: { userId: customer.userId, productId: prod(i).id } },
        create: { userId: customer.userId, productId: prod(i).id },
        update: {},
      });
    }
  });

  await step('Customer live cart', async () => {
    const count = await prisma.cartItem.count({ where: { userId: customer.userId } });
    if (count > 0) return;
    for (const [i, qty] of [[1, 1], [4, 2], [6, 1]] as const) {
      await prisma.cartItem.create({
        data: { userId: customer.userId, productId: prod(i).id, quantity: qty },
      });
    }
  });

  await step('Additional reviewers (realistic rating spread)', async () => {
    const reviewers = [
      { email: 'meera.reviews@example.com', name: 'Meera Iyer' },
      { email: 'kabir.reviews@example.com', name: 'Kabir Singh' },
      { email: 'divya.reviews@example.com', name: 'Divya Patel' },
      { email: 'raghav.reviews@example.com', name: 'Raghav Menon' },
    ];
    const passwordHash = await bcrypt.hash(MERCHANT_PASSWORD, 12);
    const userIds: number[] = [];
    for (const r of reviewers) {
      let u = await prisma.user.findUnique({ where: { email: r.email }, select: { id: true } });
      if (!u) u = await prisma.user.create({ data: { email: r.email, name: r.name, passwordHash, role: 'CUSTOMER', acceptedAt: new Date() }, select: { id: true } });
      userIds.push(u.id);
    }
    const blurbs = [
      { rating: 5, title: 'Exactly as described', body: 'Genuine product, quick delivery, well packed.' },
      { rating: 4, title: 'Good value', body: 'Works great, minor niggles but happy overall.' },
      { rating: 5, title: 'Highly recommend', body: 'Second purchase from this shop, never disappoints.' },
      { rating: 3, title: 'Decent', body: 'Does the job. Nothing extraordinary at this price.' },
    ];
    const touched = new Set<number>();
    for (let u = 0; u < userIds.length; u++) {
      for (const off of [0, 3, 6]) {
        const p = prod((u * 2 + off) % PRODUCTS.length);
        const b = blurbs[(u + off) % blurbs.length];
        await prisma.productReview.upsert({
          where: { productId_userId: { productId: p.id, userId: userIds[u] } },
          create: { productId: p.id, userId: userIds[u], rating: b.rating, title: b.title, body: b.body },
          update: { rating: b.rating, title: b.title, body: b.body },
        });
        touched.add(p.id);
      }
    }
    for (const pid of touched) {
      const agg = await prisma.productReview.aggregate({ where: { productId: pid }, _avg: { rating: true }, _count: true });
      await prisma.product.update({ where: { id: pid }, data: { ratingAvg: agg._avg.rating ?? 0, ratingCount: agg._count } });
    }
  });

  await step('Low-stock products (trigger alerts)', async () => {
    const targets = [prod(2).id, prod(7).id];
    for (const id of targets) {
      await prisma.product.update({ where: { id }, data: { stockQuantity: 3 } });
    }
  });

  await step('Notifications', async () => {
    const count = await prisma.notification.count({ where: { userId } });
    if (count >= 3) return;
    await prisma.notification.createMany({
      data: [
        { userId, kind: 'ORDER_PLACED', title: 'New order received', body: 'Rohit Sharma placed an order for 3 items.' },
        { userId, kind: 'PAYMENT_RECEIVED', title: 'Payment received', body: '₹5,000 received via UPI.' },
        { userId, kind: 'LOW_STOCK', title: 'Low stock alert', body: 'Nimbus Vortex 14 OLED is running low.' },
        { userId, kind: 'RETURN_REQUESTED', title: 'Return requested', body: 'A return was requested on order for Aether X12 Pro.' },
      ],
    });
  });

  await step('Trending events + recompute', async () => {
    const products = await prisma.product.findMany({ where: { shopId, isActive: true, isPublished: true }, select: { id: true } });
    const rows: { clientUuid: string; eventType: 'IMPRESSION' | 'TAP' | 'ADD_TO_CART' | 'PURCHASE' | 'WISHLIST_ADD'; productId: number; sessionId: string; occurredAt: Date }[] = [];
    const now = Date.now();
    for (const p of products) {
      const lift = 1 + Math.random() * 2;
      const counts = { IMPRESSION: Math.round(120 * lift), TAP: Math.round(25 * lift), ADD_TO_CART: Math.round(6 * lift), PURCHASE: Math.round(2 * lift), WISHLIST_ADD: Math.round(4 * lift) } as const;
      for (const [eventType, count] of Object.entries(counts) as Array<[keyof typeof counts, number]>) {
        for (let i = 0; i < count; i++) {
          rows.push({ clientUuid: crypto.randomUUID(), eventType, productId: p.id, sessionId: `seed-${crypto.randomUUID().slice(0, 8)}`, occurredAt: new Date(now - Math.random() * 12 * 3600e3) });
        }
      }
    }
    if (rows.length) await prisma.productEvent.createMany({ data: rows, skipDuplicates: true });
    await trendingService.recomputeWindow();
  });

  await step('Analytics roll-ups (recompute every day in the window)', async () => {
    for (let d = HISTORY_DAYS + 1; d >= 0; d--) {
      await recomputeDay(shopId, istDateUTC(daysAgo(d, 12)));
    }
    console.log(`      (recomputed ${HISTORY_DAYS + 2} days; ${touchedDays.size} had money movement)`);
  });

  console.log(`\n${failures === 0 ? '✓ All features seeded.' : `⚠ Done with ${failures} feature failure(s) above.`}`);
  console.log('\nLog in on the MERCHANT app:');
  console.log(`  email:    ${MERCHANT_EMAIL}`);
  console.log(`  password: ${MERCHANT_PASSWORD}`);
  console.log('\nLog in on the CUSTOMER app (linked buyer — orders/quotes/returns/reviews):');
  console.log(`  email:    ${CUSTOMER_EMAIL}`);
  console.log(`  password: ${CUSTOMER_PASSWORD}\n`);
}

main()
  .catch((err) => {
    console.error('\n✗ Seed aborted:', err);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

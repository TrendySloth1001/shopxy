import 'dotenv/config';
import bcrypt from 'bcrypt';
import prisma from '../infra/db/prisma.js';
import { productsService } from '../modules/products/products.service.js';
import { trendingService } from '../modules/trending/trending.service.js';
import crypto from 'crypto';

const TARGET_EMAIL = 'nkumawat8956@gmail.com';
const TARGET_PASSWORD = 'N12345678';
const TARGET_NAME = 'Nikhil Kumawat';
const TARGET_SHOP_NAME = 'VoltKart Electronics';

function slugifyShop(input: string): string {
  return input.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
}

async function uniqueShopSlug(base: string): Promise<string> {
  let candidate = base || 'shop';
  let suffix = 1;
  for (;;) {
    const hit = await prisma.shop.findUnique({
      where: { slug: candidate },
      select: { id: true },
    });
    if (!hit) return candidate;
    suffix += 1;
    candidate = `${base}-${suffix}`;
  }
}

async function ensureMerchant(): Promise<{ userId: number; shopId: number }> {
  let user = await prisma.user.findUnique({
    where: { email: TARGET_EMAIL },
    select: { id: true, role: true },
  });

  if (!user) {
    const passwordHash = await bcrypt.hash(TARGET_PASSWORD, 12);
    const slug = await uniqueShopSlug(slugifyShop(TARGET_SHOP_NAME));
    const created = await prisma.$transaction(async (tx) => {
      const u = await tx.user.create({
        data: {
          email: TARGET_EMAIL,
          name: TARGET_NAME,
          passwordHash,
          role: 'OWNER',
          shopName: TARGET_SHOP_NAME,
          acceptedAt: new Date(),
        },
        select: { id: true },
      });
      const s = await tx.shop.create({
        data: {
          ownerUserId: u.id,
          name: TARGET_SHOP_NAME,
          slug,
          isPublished: true,
        },
        select: { id: true },
      });
      await tx.shopMember.create({
        data: { shopId: s.id, userId: u.id, role: 'OWNER' },
      });
      return { userId: u.id, shopId: s.id };
    });
    console.log(`✓ Created OWNER ${TARGET_EMAIL} (id=${created.userId}) + shop "${TARGET_SHOP_NAME}" (id=${created.shopId})`);
    return created;
  }

  if (user.role !== 'OWNER') {
    throw new Error(
      `${TARGET_EMAIL} already exists with role ${user.role}. ` +
        `Either delete that account or run \`npx prisma migrate reset --force\` before seeding.`,
    );
  }

  let shop = await prisma.shop.findUnique({
    where: { ownerUserId: user.id },
    select: { id: true, isPublished: true },
  });
  if (!shop) {
    const slug = await uniqueShopSlug(slugifyShop(TARGET_SHOP_NAME));
    shop = await prisma.shop.create({
      data: {
        ownerUserId: user.id,
        name: TARGET_SHOP_NAME,
        slug,
        isPublished: true,
      },
      select: { id: true, isPublished: true },
    });
    await prisma.shopMember.upsert({
      where: { userId: user.id },
      create: { shopId: shop.id, userId: user.id, role: 'OWNER' },
      update: { shopId: shop.id, role: 'OWNER' },
    });
    console.log(`✓ Created missing shop for ${TARGET_EMAIL} (shopId=${shop.id})`);
  } else if (!shop.isPublished) {
    await prisma.shop.update({
      where: { id: shop.id },
      data: { isPublished: true },
    });
    console.log(`✓ Published existing shop (shopId=${shop.id})`);
  } else {
    console.log(`✓ Found existing merchant ${TARGET_EMAIL} (userId=${user.id}, shopId=${shop.id})`);
  }
  return { userId: user.id, shopId: shop.id };
}

async function categoryIdBySlug(slug: string): Promise<number | undefined> {
  const row = await prisma.category.findUnique({
    where: { slug },
    select: { id: true },
  });
  return row?.id;
}

const ux = (id: string): string =>
  `https://images.unsplash.com/${id}?w=900&h=900&fit=crop&auto=format&q=70`;

type SeedProduct = Parameters<typeof productsService.createProduct>[0] & {
  categorySlug?: string;
};

const PRODUCTS: SeedProduct[] = [
  {
    name: 'Aether X12 Pro 5G',
    description:
      'A pro-grade 5G flagship with a 6.78″ LTPO AMOLED, triple 50MP rear camera, and 120W SuperVOOC charging.',
    sku: 'AETHER-X12P',
    barcode: '8901234500011',
    hsnCode: '85171300',
    brand: 'Aether',
    mrp: 79999,
    sellingPrice: 64999,
    purchasePrice: 51000,
    taxPercent: 18,
    stockQuantity: 60,
    lowStockThreshold: 10,
    unit: 'PCS',
    categorySlug: 'smartphones',
    tags: ['5G', 'AMOLED', 'flagship', 'fast-charging'],
    highlights: [
      '6.78″ LTPO3 AMOLED · 1.5K · 120Hz · 3000 nits peak',
      'Snapdragon 8 Gen 3 · 12GB LPDDR5X · 256GB UFS 4.0',
      'Triple 50MP camera: wide + 3x telephoto + ultrawide, OIS on all',
      '5400mAh dual-cell · 120W wired + 50W wireless SuperVOOC',
      'IP68 dust + water resistance, Gorilla Glass Victus 2',
      'Stereo speakers tuned by Bang & Olufsen, Hi-Res Audio',
      'Aether OS 14 (Android 14) with 4 OS + 5 security updates',
      'In-screen ultrasonic fingerprint + Face Unlock 3D',
    ],
    specs: [
      {
        title: 'General',
        tab: 'General',
        rows: [
          { label: 'In the box', value: 'Phone, 120W charger, USB-C cable, case, SIM ejector, docs' },
          { label: 'Model number', value: 'AX12P-256-OB' },
          { label: 'Launch year', value: '2026' },
          { label: 'Colour options', value: 'Obsidian Black, Glacier Silver, Solar Amber' },
          { label: 'Warranty', value: '1 year manufacturer + 6 months on charger' },
        ],
      },
      {
        title: 'Display',
        tab: 'Display',
        rows: [
          { label: 'Size', value: '6.78 inches' },
          { label: 'Type', value: 'LTPO3 AMOLED, 10-bit' },
          { label: 'Resolution', value: '1264 × 2780 (1.5K)' },
          { label: 'Refresh rate', value: '1–120Hz adaptive' },
          { label: 'Peak brightness', value: '3000 nits (HDR)' },
          { label: 'Protection', value: 'Corning Gorilla Glass Victus 2' },
        ],
      },
      {
        title: 'Performance',
        tab: 'Performance',
        rows: [
          { label: 'SoC', value: 'Qualcomm Snapdragon 8 Gen 3 (4nm)' },
          { label: 'GPU', value: 'Adreno 750' },
          { label: 'RAM', value: '12GB LPDDR5X' },
          { label: 'Storage', value: '256GB / 512GB UFS 4.0' },
          { label: 'Cooling', value: 'Vapor chamber, 4860 mm²' },
        ],
      },
      {
        title: 'Camera',
        tab: 'Camera',
        rows: [
          { label: 'Main', value: '50MP, f/1.55, OIS, 1/1.4″ sensor' },
          { label: 'Telephoto', value: '50MP, f/2.5, 3x optical, OIS' },
          { label: 'Ultrawide', value: '50MP, f/2.2, 122°, OIS' },
          { label: 'Front', value: '32MP, f/2.4, autofocus' },
          { label: 'Video', value: '8K @ 30fps, 4K @ 60fps Dolby Vision' },
        ],
      },
      {
        title: 'Battery & Charging',
        tab: 'Battery',
        rows: [
          { label: 'Capacity', value: '5400 mAh dual-cell' },
          { label: 'Wired charging', value: '120W SuperVOOC (0–100% in 21 min)' },
          { label: 'Wireless charging', value: '50W AirVOOC' },
          { label: 'Reverse wireless', value: '10W' },
        ],
      },
      {
        title: 'Connectivity',
        tab: 'Connectivity',
        rows: [
          { label: 'SIM', value: 'Dual nano-SIM + eSIM' },
          { label: '5G', value: 'Sub-6 + mmWave' },
          { label: 'Wi-Fi', value: 'Wi-Fi 7 (802.11be)' },
          { label: 'Bluetooth', value: '5.4 LE Audio' },
          { label: 'NFC', value: 'Yes' },
          { label: 'USB', value: 'Type-C 3.2 Gen 2 (10 Gbps)' },
        ],
      },
    ],
    offers: [
      { kind: 'BANK', headline: '10% instant discount on HDFC Credit Cards', detail: 'Up to ₹3,000 on a minimum order of ₹40,000. T&C apply.' },
      { kind: 'COUPON', headline: 'Extra ₹2000 off with code AETHER2K', detail: 'Auto-applied at checkout for first-time buyers.', code: 'AETHER2K' },
      { kind: 'EMI', headline: 'No-cost EMI from ₹3,611/mo', detail: '18 months tenure on Bajaj Finserv.' },
      { kind: 'EXCHANGE', headline: 'Up to ₹18,000 off on exchange', detail: 'Trade-in your old device at doorstep pickup.' },
    ],
    contentBlocks: [
      {
        kind: 'HERO',
        imageUrl: ux('photo-1610945265064-0e34e5519bbf'),
        headline: 'Engineered to outpace the everyday.',
        subtext: 'Snapdragon 8 Gen 3 · Triple OIS cameras · 120W charging in 21 minutes.',
      },
      {
        kind: 'FEATURE',
        imageUrl: ux('photo-1606811971618-4486d14f3f99'),
        side: 'LEFT',
        title: 'A camera system that thinks in light.',
        body: 'Triple 50MP sensors with optical stabilisation on every lens. The Aether Imaging Engine fuses 14 frames in 0.2s, so a moving subject looks like a deliberate one.',
      },
      {
        kind: 'FEATURE',
        imageUrl: ux('photo-1592434134753-a70baf7979d5'),
        side: 'RIGHT',
        title: 'All day. In twenty-one minutes.',
        body: '120W SuperVOOC pours a full day of charge into the 5400 mAh cell before your coffee cools. Battery longevity is preserved by a dual-cell design rated for 1600 cycles.',
      },
      {
        kind: 'COMPARISON',
        columns: [
          { label: 'X12 Pro', values: ['6.78″ 1.5K', 'SD 8 Gen 3', '5400 mAh', '120W', 'IP68'] },
          { label: 'X11 Pro', values: ['6.7″ FHD+', 'SD 8 Gen 2', '5000 mAh', '80W', 'IP67'] },
          { label: 'X12', values: ['6.7″ FHD+', 'SD 8 Gen 2', '5000 mAh', '67W', 'IP65'] },
        ],
        rows: ['Display', 'Chipset', 'Battery', 'Charging', 'Water resistance'],
      },
      {
        kind: 'GALLERY',
        images: [
          { url: ux('photo-1565849904461-04a58ad377e0'), caption: 'Solar Amber finish under studio light.' },
          { url: ux('photo-1592750475338-74b7b21085ab'), caption: 'Camera island, machined aluminium.' },
          { url: ux('photo-1511707171634-5f897ff02aa9'), caption: 'In-hand at 8.4mm thick.' },
        ],
      },
      {
        kind: 'TEXT',
        markdown:
          '**In the box.** Phone, 120W charger, 1.5m USB-C cable, transparent case, SIM ejector, documentation. **Care.** Wipe with a soft, dry cloth. Charge in temperatures between 0°C and 35°C. Re-pair the case if Bluetooth Quick Pair fails to surface.',
      },
    ],
    variantAxes: [
      { name: 'Colour', values: ['Obsidian Black', 'Glacier Silver', 'Solar Amber'] },
      { name: 'Storage', values: ['256GB', '512GB'] },
    ],
    variants: [
      { sku: 'AETHER-X12P-OB-256', barcode: '8901234500021', attributes: { 'Colour': 'Obsidian Black', 'Storage': '256GB' }, mrp: 79999, sellingPrice: 64999, purchasePrice: 51000, stockQuantity: 15, imageUrls: [ux('photo-1610945265064-0e34e5519bbf'), ux('photo-1592750475338-74b7b21085ab')] },
      { sku: 'AETHER-X12P-OB-512', barcode: '8901234500022', attributes: { 'Colour': 'Obsidian Black', 'Storage': '512GB' }, mrp: 86999, sellingPrice: 70999, purchasePrice: 55500, stockQuantity: 8, imageUrls: [ux('photo-1610945265064-0e34e5519bbf')] },
      { sku: 'AETHER-X12P-GS-256', barcode: '8901234500023', attributes: { 'Colour': 'Glacier Silver', 'Storage': '256GB' }, mrp: 79999, sellingPrice: 64999, purchasePrice: 51000, stockQuantity: 12, imageUrls: [ux('photo-1592434134753-a70baf7979d5')] },
      { sku: 'AETHER-X12P-GS-512', barcode: '8901234500024', attributes: { 'Colour': 'Glacier Silver', 'Storage': '512GB' }, mrp: 86999, sellingPrice: 70999, purchasePrice: 55500, stockQuantity: 6, imageUrls: [ux('photo-1592434134753-a70baf7979d5')] },
      { sku: 'AETHER-X12P-SA-256', barcode: '8901234500025', attributes: { 'Colour': 'Solar Amber', 'Storage': '256GB' }, mrp: 79999, sellingPrice: 64999, purchasePrice: 51000, stockQuantity: 14, imageUrls: [ux('photo-1565849904461-04a58ad377e0')] },
      { sku: 'AETHER-X12P-SA-512', barcode: '8901234500026', attributes: { 'Colour': 'Solar Amber', 'Storage': '512GB' }, mrp: 86999, sellingPrice: 70999, purchasePrice: 55500, stockQuantity: 5, imageUrls: [ux('photo-1565849904461-04a58ad377e0')] },
    ],
  },

  {
    name: 'PulseAir Pods Pro (2nd Gen)',
    description: 'True wireless earbuds with adaptive ANC, spatial audio, and 32-hour total playback with the wireless case.',
    sku: 'PULSE-PODSPRO2',
    barcode: '8902345600011',
    hsnCode: '85183000',
    brand: 'PulseAir',
    mrp: 12999,
    sellingPrice: 8999,
    purchasePrice: 5400,
    taxPercent: 18,
    stockQuantity: 200,
    lowStockThreshold: 25,
    unit: 'PCS',
    categorySlug: 'earbuds',
    tags: ['ANC', 'true-wireless', 'spatial-audio'],
    highlights: [
      'Adaptive ANC silences up to 42 dB of ambient noise',
      'Spatial Audio with dynamic head tracking',
      'Up to 8h playback (buds) · 32h total with case',
      'Wireless charging Qi + USB-C',
      'IPX5 sweat & splash resistance',
      'Bluetooth 5.4 multipoint (2 simultaneous devices)',
      'Custom 11mm titanium driver, LDAC + AAC + LC3 codecs',
    ],
    specs: [
      {
        title: 'Audio',
        tab: 'Audio',
        rows: [
          { label: 'Driver', value: '11mm titanium-coated dynamic' },
          { label: 'Codecs', value: 'LDAC, AAC, LC3, SBC' },
          { label: 'ANC depth', value: '42 dB peak' },
          { label: 'Spatial audio', value: 'Yes, with head tracking' },
        ],
      },
      {
        title: 'Battery',
        tab: 'Battery',
        rows: [
          { label: 'Buds', value: 'Up to 8h (ANC off)' },
          { label: 'Total with case', value: 'Up to 32h' },
          { label: 'Quick charge', value: '10 min → 90 min playback' },
          { label: 'Charging', value: 'USB-C + Qi wireless' },
        ],
      },
      {
        title: 'Connectivity',
        tab: 'Connectivity',
        rows: [
          { label: 'Bluetooth', value: '5.4, multipoint' },
          { label: 'Range', value: '15m line-of-sight' },
          { label: 'Latency mode', value: 'Game mode <60ms' },
        ],
      },
    ],
    offers: [
      { kind: 'BANK', headline: '5% cashback on ICICI Debit Cards', detail: 'Up to ₹500.' },
      { kind: 'COUPON', headline: 'Buy 2 save ₹1500', code: 'PAIRUP', detail: 'Auto-applied when 2 units of any PulseAir product are in cart.' },
      { kind: 'EMI', headline: '3-month no-cost EMI', detail: 'Available on most major cards.' },
    ],
    contentBlocks: [
      { kind: 'HERO', imageUrl: ux('photo-1606220588913-b3aacb4d2f46'), headline: 'Heard. Not interrupted.', subtext: 'Adaptive ANC. Spatial audio. 32 hours in a pocket.' },
      { kind: 'FEATURE', imageUrl: ux('photo-1583394838336-acd977736f90'), side: 'LEFT', title: 'Two devices. Zero juggling.', body: 'Multipoint Bluetooth keeps your laptop and phone connected at the same time. Pick up a call mid-podcast and they handle the switch.' },
      { kind: 'GALLERY', images: [
        { url: ux('photo-1606220588913-b3aacb4d2f46') },
        { url: ux('photo-1583394838336-acd977736f90'), caption: 'Compact charging case with Qi pad.' },
      ]},
    ],
    variantAxes: [{ name: 'Colour', values: ['Cloud White', 'Midnight', 'Sage'] }],
    variants: [
      { sku: 'PULSE-PODSPRO2-WH', barcode: '8902345600021', attributes: { 'Colour': 'Cloud White' }, mrp: 12999, sellingPrice: 8999, purchasePrice: 5400, stockQuantity: 80, imageUrls: [ux('photo-1606220588913-b3aacb4d2f46')] },
      { sku: 'PULSE-PODSPRO2-MN', barcode: '8902345600022', attributes: { 'Colour': 'Midnight' }, mrp: 12999, sellingPrice: 8999, purchasePrice: 5400, stockQuantity: 70, imageUrls: [ux('photo-1583394838336-acd977736f90')] },
      { sku: 'PULSE-PODSPRO2-SG', barcode: '8902345600023', attributes: { 'Colour': 'Sage' }, mrp: 12999, sellingPrice: 8999, purchasePrice: 5400, stockQuantity: 50, imageUrls: [ux('photo-1505740420928-5e560c06d30e')] },
    ],
  },

  {
    name: 'Nimbus Vortex 14 OLED',
    description: '14″ 3K OLED ultrabook with Intel Core Ultra 9 and dedicated RTX 4060 graphics in a 1.49 kg chassis.',
    sku: 'NIMBUS-V14',
    barcode: '8903456700011',
    hsnCode: '84713010',
    brand: 'Nimbus',
    mrp: 159999,
    sellingPrice: 134999,
    purchasePrice: 108000,
    taxPercent: 18,
    stockQuantity: 30,
    lowStockThreshold: 5,
    unit: 'PCS',
    categorySlug: 'laptops',
    tags: ['OLED', 'creator', 'thin-light', 'RTX'],
    highlights: [
      '14″ 3K (2880×1800) OLED · 120Hz · 100% DCI-P3 · VESA DisplayHDR True Black 500',
      'Intel Core Ultra 9 185H · 16 cores · NPU for on-device AI',
      'NVIDIA GeForce RTX 4060 8GB · 75W TGP',
      '32GB LPDDR5X-7500 · 1TB PCIe 4.0 SSD',
      '1.49 kg · CNC aluminium · MIL-STD-810H tested',
      '76 Wh battery · up to 14h video playback · 100W USB-C PD',
      'Thunderbolt 4 ×2, USB-A, HDMI 2.1, SD Express card reader',
    ],
    specs: [
      {
        title: 'Display',
        tab: 'Display',
        rows: [
          { label: 'Size', value: '14 inches' },
          { label: 'Panel', value: '3K OLED, 120Hz' },
          { label: 'Resolution', value: '2880 × 1800' },
          { label: 'Brightness', value: '600 nits HDR peak' },
          { label: 'Touch', value: 'Yes, 10-point capacitive' },
        ],
      },
      {
        title: 'Performance',
        tab: 'Performance',
        rows: [
          { label: 'CPU', value: 'Intel Core Ultra 9 185H, 16C/22T' },
          { label: 'GPU', value: 'NVIDIA GeForce RTX 4060 8GB' },
          { label: 'RAM', value: '32GB LPDDR5X-7500 (soldered)' },
          { label: 'Storage', value: '1TB PCIe 4.0 NVMe SSD' },
        ],
      },
      {
        title: 'Battery & Power',
        tab: 'Battery',
        rows: [
          { label: 'Capacity', value: '76 Wh' },
          { label: 'Adapter', value: '180W barrel + 100W USB-C PD support' },
          { label: 'Battery life', value: 'Up to 14h video playback' },
        ],
      },
      {
        title: 'Ports & Connectivity',
        tab: 'Connectivity',
        rows: [
          { label: 'Thunderbolt 4', value: '2x USB-C' },
          { label: 'USB-A', value: '1x USB 3.2 Gen 2' },
          { label: 'HDMI', value: 'HDMI 2.1' },
          { label: 'SD card', value: 'SD Express 7.0' },
          { label: 'Wi-Fi', value: 'Wi-Fi 7' },
          { label: 'Bluetooth', value: '5.4' },
        ],
      },
    ],
    offers: [
      { kind: 'BANK', headline: '₹8,000 off on Axis Bank Credit Cards', detail: 'Minimum order ₹100,000.' },
      { kind: 'COUPON', headline: 'Free 24-month accidental damage cover', code: 'NIMBUSCARE', detail: 'Voucher emailed within 24h of dispatch.' },
      { kind: 'EMI', headline: 'No-cost EMI up to 12 months', detail: 'Available on selected credit cards.' },
      { kind: 'EXCHANGE', headline: 'Up to ₹40,000 off on old laptop exchange', detail: 'Doorstep evaluation.' },
    ],
    contentBlocks: [
      { kind: 'HERO', imageUrl: ux('photo-1496181133206-80ce9b88a853'), headline: 'A studio. In 1.49 kilograms.', subtext: '3K OLED. Core Ultra 9. RTX 4060. Designed in collaboration with colourists.' },
      { kind: 'FEATURE', imageUrl: ux('photo-1517336714731-489689fd1ca8'), side: 'RIGHT', title: 'Calibrated at the factory.', body: 'Every Vortex 14 ships with a per-unit Delta-E < 1 calibration report. The OLED panel covers 100% DCI-P3 and is Pantone Validated for print-accurate work.' },
      { kind: 'FEATURE', imageUrl: ux('photo-1587202372775-e229f172b9d7'), side: 'LEFT', title: 'Cool enough to keep up.', body: 'Twin vapour chambers and dual 102-blade fans keep CPU + GPU package power at 110W indefinitely, without lap-warming.' },
      { kind: 'COMPARISON', columns: [
        { label: 'Vortex 14', values: ['Ultra 9 185H', 'RTX 4060 8GB', '3K OLED', '32GB', '1.49 kg'] },
        { label: 'Vortex 14 Air', values: ['Ultra 7 155H', 'Integrated', '2.8K OLED', '16GB', '1.32 kg'] },
        { label: 'Vortex 16 Pro', values: ['Ultra 9 185HX', 'RTX 4070 8GB', '4K Mini-LED', '64GB', '2.10 kg'] },
      ], rows: ['CPU', 'GPU', 'Display', 'RAM', 'Weight'] },
      { kind: 'TEXT', markdown: 'Ships with Windows 11 Pro and a 24-month international warranty. Service: book a pickup from the Nimbus app or any authorised partner.' },
    ],
    variantAxes: [
      { name: 'Memory', values: ['32GB / 1TB', '32GB / 2TB', '64GB / 2TB'] },
    ],
    variants: [
      { sku: 'NIMBUS-V14-32-1T', barcode: '8903456700021', attributes: { 'Memory': '32GB / 1TB' }, mrp: 159999, sellingPrice: 134999, purchasePrice: 108000, stockQuantity: 15, imageUrls: [ux('photo-1496181133206-80ce9b88a853')] },
      { sku: 'NIMBUS-V14-32-2T', barcode: '8903456700022', attributes: { 'Memory': '32GB / 2TB' }, mrp: 169999, sellingPrice: 144999, purchasePrice: 116000, stockQuantity: 10, imageUrls: [ux('photo-1517336714731-489689fd1ca8')] },
      { sku: 'NIMBUS-V14-64-2T', barcode: '8903456700023', attributes: { 'Memory': '64GB / 2TB' }, mrp: 189999, sellingPrice: 164999, purchasePrice: 132000, stockQuantity: 5, imageUrls: [ux('photo-1587202372775-e229f172b9d7')] },
    ],
  },

  {
    name: 'ChronoFit S3 AMOLED',
    description: 'Lightweight smartwatch with a 1.43″ AMOLED, dual-frequency GPS, and 14-day battery life.',
    sku: 'CHRONO-S3',
    barcode: '8904567800011',
    hsnCode: '91029900',
    brand: 'ChronoFit',
    mrp: 9999,
    sellingPrice: 6499,
    purchasePrice: 3800,
    taxPercent: 18,
    stockQuantity: 150,
    lowStockThreshold: 20,
    unit: 'PCS',
    categorySlug: 'smartwatches',
    tags: ['fitness', 'AMOLED', 'GPS'],
    highlights: [
      '1.43″ AMOLED, 466×466, always-on display',
      'Dual-frequency GPS (L1 + L5) for accurate route tracking',
      'Up to 14 days battery (typical use), 7 days with AOD',
      '5ATM water resistance — pool & open-water swimming',
      '120+ sport modes with auto-detect',
      'SpO₂, heart rate, sleep stages, stress, menstrual tracking',
      'Bluetooth calling with built-in mic + speaker',
    ],
    specs: [
      { title: 'Display', tab: 'Display', rows: [
        { label: 'Size', value: '1.43 inches' },
        { label: 'Resolution', value: '466 × 466' },
        { label: 'Always-on display', value: 'Yes' },
      ]},
      { title: 'Health Sensors', tab: 'Health', rows: [
        { label: 'Heart rate', value: 'Optical, 24/7' },
        { label: 'SpO₂', value: 'Spot check + overnight' },
        { label: 'ECG', value: 'No' },
        { label: 'Sleep tracking', value: 'Stages + score' },
      ]},
      { title: 'Battery', tab: 'Battery', rows: [
        { label: 'Capacity', value: '420 mAh' },
        { label: 'Typical', value: '14 days' },
        { label: 'AOD on', value: '7 days' },
        { label: 'GPS continuous', value: '40 hours' },
      ]},
      { title: 'Connectivity', tab: 'Connectivity', rows: [
        { label: 'Bluetooth', value: '5.3' },
        { label: 'GPS', value: 'L1 + L5 dual frequency' },
        { label: 'Compatible with', value: 'Android 8+, iOS 13+' },
      ]},
    ],
    offers: [
      { kind: 'BANK', headline: '7% instant discount on SBI Credit Cards', detail: 'Up to ₹500.' },
      { kind: 'COUPON', headline: 'Free milanese strap with code STRAPFREE', code: 'STRAPFREE' },
      { kind: 'EMI', headline: '6-month no-cost EMI' },
    ],
    contentBlocks: [
      { kind: 'HERO', imageUrl: ux('photo-1523275335684-37898b6baf30'), headline: 'Train. Sleep. Repeat.', subtext: 'Two weeks of battery. Dual-frequency GPS. AMOLED that survives a Sunday long run.' },
      { kind: 'FEATURE', imageUrl: ux('photo-1546868871-7041f2a55e12'), side: 'LEFT', title: 'Routes that stay on the trail.', body: 'L1+L5 dual-band GPS removes urban canyon drift. Map matching reads the road network so a 5K through downtown doesn\'t look like a 5.4K.' },
    ],
    variantAxes: [
      { name: 'Case', values: ['Graphite', 'Rose Gold', 'Silver'] },
      { name: 'Strap', values: ['Sport Band', 'Milanese Loop'] },
    ],
    variants: [
      { sku: 'CHRONO-S3-GR-SB', barcode: '8904567800021', attributes: { 'Case': 'Graphite', 'Strap': 'Sport Band' }, mrp: 9999, sellingPrice: 6499, purchasePrice: 3800, stockQuantity: 40, imageUrls: [ux('photo-1546868871-7041f2a55e12')] },
      { sku: 'CHRONO-S3-GR-ML', barcode: '8904567800022', attributes: { 'Case': 'Graphite', 'Strap': 'Milanese Loop' }, mrp: 10999, sellingPrice: 7299, purchasePrice: 4200, stockQuantity: 25, imageUrls: [ux('photo-1524805444758-089113d48a6d')] },
      { sku: 'CHRONO-S3-RG-SB', barcode: '8904567800023', attributes: { 'Case': 'Rose Gold', 'Strap': 'Sport Band' }, mrp: 9999, sellingPrice: 6499, purchasePrice: 3800, stockQuantity: 30, imageUrls: [ux('photo-1523275335684-37898b6baf30')] },
      { sku: 'CHRONO-S3-RG-ML', barcode: '8904567800024', attributes: { 'Case': 'Rose Gold', 'Strap': 'Milanese Loop' }, mrp: 10999, sellingPrice: 7299, purchasePrice: 4200, stockQuantity: 20, imageUrls: [ux('photo-1523275335684-37898b6baf30')] },
      { sku: 'CHRONO-S3-SI-SB', barcode: '8904567800025', attributes: { 'Case': 'Silver', 'Strap': 'Sport Band' }, mrp: 9999, sellingPrice: 6499, purchasePrice: 3800, stockQuantity: 20, imageUrls: [ux('photo-1557935728-e6d1eaabe558')] },
      { sku: 'CHRONO-S3-SI-ML', barcode: '8904567800026', attributes: { 'Case': 'Silver', 'Strap': 'Milanese Loop' }, mrp: 10999, sellingPrice: 7299, purchasePrice: 4200, stockQuantity: 15, imageUrls: [ux('photo-1524805444758-089113d48a6d')] },
    ],
  },

  {
    name: 'BassRock Cube Mini',
    description: 'Pocketable Bluetooth speaker with stereo pairing, 360° sound, and 18-hour playback.',
    sku: 'BASS-CUBEMINI',
    barcode: '8905678900011',
    hsnCode: '85182900',
    brand: 'BassRock',
    mrp: 4999,
    sellingPrice: 3299,
    purchasePrice: 1800,
    taxPercent: 18,
    stockQuantity: 180,
    lowStockThreshold: 30,
    unit: 'PCS',
    categorySlug: 'bluetooth-speakers',
    tags: ['portable', 'IPX7', 'stereo-pair'],
    highlights: [
      '360° sound from dual passive radiators',
      'Up to 18 hours playback at 60% volume',
      'IPX7 — survives a 1m dunk for 30 minutes',
      'TWS stereo pairing — link two for left/right',
      'Bluetooth 5.3 with multipoint',
      'USB-C charging in under 2 hours',
    ],
    specs: [
      { title: 'Audio', tab: 'Audio', rows: [
        { label: 'Output', value: '10W RMS' },
        { label: 'Driver', value: '40mm full-range + dual passive radiators' },
        { label: 'Frequency response', value: '80 Hz – 20 kHz' },
      ]},
      { title: 'Battery', tab: 'Battery', rows: [
        { label: 'Capacity', value: '2400 mAh' },
        { label: 'Playback', value: '18 hours @ 60% volume' },
        { label: 'Charging', value: 'USB-C, 1h45m to full' },
      ]},
    ],
    offers: [
      { kind: 'COUPON', headline: '₹400 off with code SOUNDON', code: 'SOUNDON' },
      { kind: 'BANK', headline: '5% cashback on HSBC Credit Cards' },
    ],
    contentBlocks: [
      { kind: 'HERO', imageUrl: ux('photo-1545454675-3531b543be5d'), headline: 'A pocket. A picnic. A pool.', subtext: 'Eighteen hours of sound that follows you.' },
      { kind: 'GALLERY', images: [
        { url: ux('photo-1545454675-3531b543be5d') },
        { url: ux('photo-1558379850-2b9bb7e7f59f') },
      ]},
    ],
    variantAxes: [{ name: 'Colour', values: ['Charcoal', 'Coral', 'Forest'] }],
    variants: [
      { sku: 'BASS-CUBEMINI-CH', barcode: '8905678900021', attributes: { 'Colour': 'Charcoal' }, mrp: 4999, sellingPrice: 3299, purchasePrice: 1800, stockQuantity: 70, imageUrls: [ux('photo-1545454675-3531b543be5d')] },
      { sku: 'BASS-CUBEMINI-CR', barcode: '8905678900022', attributes: { 'Colour': 'Coral' }, mrp: 4999, sellingPrice: 3299, purchasePrice: 1800, stockQuantity: 60, imageUrls: [ux('photo-1558379850-2b9bb7e7f59f')] },
      { sku: 'BASS-CUBEMINI-FO', barcode: '8905678900023', attributes: { 'Colour': 'Forest' }, mrp: 4999, sellingPrice: 3299, purchasePrice: 1800, stockQuantity: 50, imageUrls: [ux('photo-1545454675-3531b543be5d')] },
    ],
  },

  {
    name: 'PixelPro 27Q QHD IPS',
    description: '27″ QHD IPS monitor at 165 Hz with 1ms response, 95% DCI-P3 and ergonomic stand.',
    sku: 'PIXEL-27Q',
    barcode: '8906789000011',
    hsnCode: '85285200',
    brand: 'PixelPro',
    mrp: 32999,
    sellingPrice: 24999,
    purchasePrice: 18000,
    taxPercent: 18,
    stockQuantity: 45,
    lowStockThreshold: 8,
    unit: 'PCS',
    categorySlug: 'monitors',
    tags: ['QHD', 'IPS', '165Hz'],
    highlights: [
      '27″ QHD (2560×1440) IPS panel, 165 Hz, 1ms MPRT',
      '95% DCI-P3 / 100% sRGB, factory-calibrated',
      'HDR400 with edge-lit dimming',
      'USB-C 65W power delivery, daisy-chain via DisplayPort 1.4',
      'Tilt, swivel, pivot, height-adjust ergonomic stand',
      'KVM switch built-in, picture-in-picture',
    ],
    specs: [
      { title: 'Panel', tab: 'Panel', rows: [
        { label: 'Size', value: '27 inches' },
        { label: 'Resolution', value: '2560 × 1440' },
        { label: 'Refresh rate', value: '165 Hz' },
        { label: 'Response time', value: '1 ms MPRT, 4 ms GtG' },
        { label: 'Brightness', value: '400 nits (HDR400)' },
      ]},
      { title: 'Ports', tab: 'Ports', rows: [
        { label: 'HDMI', value: '2× HDMI 2.1' },
        { label: 'DisplayPort', value: '1× DP 1.4' },
        { label: 'USB-C', value: '1× with 65W PD + DP Alt-mode' },
        { label: 'USB hub', value: '4× USB 3.2 Gen 1' },
      ]},
      { title: 'Ergonomics', tab: 'Ergonomics', rows: [
        { label: 'Tilt', value: '-5° / +21°' },
        { label: 'Height adjust', value: '130 mm' },
        { label: 'Swivel', value: '±30°' },
        { label: 'VESA mount', value: '100×100' },
      ]},
    ],
    offers: [
      { kind: 'BANK', headline: '₹2,000 instant discount on Kotak Credit Cards' },
      { kind: 'EMI', headline: '9-month no-cost EMI' },
      { kind: 'EXCHANGE', headline: 'Up to ₹5,000 off on old monitor exchange' },
    ],
    contentBlocks: [
      { kind: 'HERO', imageUrl: ux('photo-1527443224154-c4a3942d3acf'), headline: 'Pixel-accurate. Frame-fast.', subtext: '165 Hz IPS with factory colour calibration.' },
      { kind: 'FEATURE', imageUrl: ux('photo-1527443224154-c4a3942d3acf'), side: 'RIGHT', title: 'One cable. Whole desk.', body: 'USB-C with 65W PD charges your laptop, drives the panel, and runs the four-port USB hub through a single cable.' },
    ],
    variantAxes: [],
    variants: [],
  },

  {
    name: 'KeyForge K75 RGB',
    description: '75% hot-swappable mechanical keyboard with gasket mount, per-key RGB, and tri-mode wireless.',
    sku: 'KEY-K75',
    barcode: '8907890100011',
    hsnCode: '84716060',
    brand: 'KeyForge',
    mrp: 14999,
    sellingPrice: 10999,
    purchasePrice: 6800,
    taxPercent: 18,
    stockQuantity: 80,
    lowStockThreshold: 12,
    unit: 'PCS',
    categorySlug: 'laptop-accessories',
    tags: ['mechanical', 'hot-swap', 'RGB'],
    highlights: [
      '75% layout — function row + dedicated arrows',
      'Gasket-mounted PCB with five layers of dampening',
      'Hot-swappable 5-pin south-facing sockets',
      'Tri-mode: USB-C, 2.4 GHz, Bluetooth 5.1 (multipoint 3 devices)',
      'PBT double-shot keycaps with shine-through legends',
      '4000 mAh battery — up to 200 hours (RGB off)',
      'Per-key south-facing RGB, VIA & QMK configurable',
    ],
    specs: [
      { title: 'Build', tab: 'Build', rows: [
        { label: 'Layout', value: '75% (84 keys)' },
        { label: 'Case', value: 'Aluminium top, polycarbonate bottom' },
        { label: 'Mount', value: 'Gasket' },
        { label: 'Weight', value: '1.2 kg' },
      ]},
      { title: 'Switches & Keycaps', tab: 'Switches', rows: [
        { label: 'Switch type', value: 'Hot-swappable, 5-pin' },
        { label: 'Pre-installed', value: 'Choose at checkout (Linear / Tactile / Clicky)' },
        { label: 'Keycaps', value: 'PBT double-shot, Cherry profile' },
        { label: 'Polling rate', value: '1000 Hz' },
      ]},
      { title: 'Connectivity', tab: 'Connectivity', rows: [
        { label: 'Wired', value: 'USB-C, detachable cable' },
        { label: '2.4 GHz', value: 'Yes, included dongle' },
        { label: 'Bluetooth', value: '5.1, multipoint up to 3 devices' },
      ]},
    ],
    offers: [
      { kind: 'COUPON', headline: '₹1,000 off with code TYPELOUD', code: 'TYPELOUD' },
      { kind: 'EMI', headline: '6-month no-cost EMI' },
    ],
    contentBlocks: [
      { kind: 'HERO', imageUrl: ux('photo-1587829741301-dc798b83add3'), headline: 'Thock. Not clack.', subtext: 'Five layers of dampening. Gasket-mounted. Built to be opened.' },
      { kind: 'FEATURE', imageUrl: ux('photo-1587829741301-dc798b83add3'), side: 'LEFT', title: 'Swap a switch in 4 seconds.', body: 'Pull the keycap, lift the switch, drop a new one in. No soldering — five-pin sockets accept every major MX-compatible switch on the market.' },
      { kind: 'COMPARISON', columns: [
        { label: 'K75', values: ['75%', 'Gasket', 'Hot-swap', 'Tri-mode'] },
        { label: 'K60', values: ['60%', 'Tray', 'Soldered', 'USB-C only'] },
        { label: 'K100', values: ['Full-size', 'Top-mount', 'Hot-swap', 'USB-C only'] },
      ], rows: ['Layout', 'Mount', 'Switches', 'Connectivity'] },
    ],
    variantAxes: [
      { name: 'Switches', values: ['Linear (Red)', 'Tactile (Brown)', 'Clicky (Blue)'] },
    ],
    variants: [
      { sku: 'KEY-K75-LIN', barcode: '8907890100021', attributes: { 'Switches': 'Linear (Red)' }, mrp: 14999, sellingPrice: 10999, purchasePrice: 6800, stockQuantity: 30, imageUrls: [ux('photo-1587829741301-dc798b83add3')] },
      { sku: 'KEY-K75-TAC', barcode: '8907890100022', attributes: { 'Switches': 'Tactile (Brown)' }, mrp: 14999, sellingPrice: 10999, purchasePrice: 6800, stockQuantity: 30, imageUrls: [ux('photo-1587829741301-dc798b83add3')] },
      { sku: 'KEY-K75-CLK', barcode: '8907890100023', attributes: { 'Switches': 'Clicky (Blue)' }, mrp: 14999, sellingPrice: 10999, purchasePrice: 6800, stockQuantity: 20, imageUrls: [ux('photo-1587829741301-dc798b83add3')] },
    ],
  },

  {
    name: 'VoltStash 20K MagFlow',
    description: 'Slim 20,000 mAh power bank with magnetic wireless charging, 100W USB-C PD, and a built-in OLED.',
    sku: 'VOLT-20K',
    barcode: '8908901200011',
    hsnCode: '85076000',
    brand: 'VoltStash',
    mrp: 5999,
    sellingPrice: 3999,
    purchasePrice: 2200,
    taxPercent: 18,
    stockQuantity: 240,
    lowStockThreshold: 40,
    unit: 'PCS',
    categorySlug: 'phone-holders',
    tags: ['fast-charge', 'PD', 'magsafe-compatible'],
    highlights: [
      '20,000 mAh — charges most phones to 100% three times',
      '100W USB-C Power Delivery, charges laptops too',
      '15W magnetic wireless on the back (MagSafe-compatible)',
      'OLED status display: remaining mAh + per-port output',
      'Three-output simultaneous charging',
      'Aviation-grade — TSA carry-on approved',
    ],
    specs: [
      { title: 'Capacity', rows: [
        { label: 'Battery', value: '20,000 mAh / 74 Wh' },
        { label: 'Phone recharges', value: '~3.4× iPhone 15 Pro' },
        { label: 'Laptop recharges', value: '~1.1× 13″ MacBook Air' },
      ]},
      { title: 'Outputs', rows: [
        { label: 'USB-C #1', value: '100W PD 3.1' },
        { label: 'USB-C #2', value: '30W PD 3.0' },
        { label: 'USB-A', value: '22.5W QC 3.0' },
        { label: 'Wireless', value: '15W magnetic' },
      ]},
      { title: 'Inputs', rows: [
        { label: 'USB-C in', value: 'Up to 65W, 0–100% in ~80 minutes' },
      ]},
    ],
    offers: [
      { kind: 'COUPON', headline: '₹600 off with code STASH600', code: 'STASH600' },
      { kind: 'BANK', headline: '5% cashback on YES Bank Credit Cards' },
    ],
    contentBlocks: [
      { kind: 'HERO', imageUrl: ux('photo-1609592424823-e4b0a92ed1d3'), headline: 'A full day. In your pocket.', subtext: 'Twenty thousand milliamp-hours that don\'t feel like it.' },
      { kind: 'TEXT', markdown: '**Air-travel safe.** 74 Wh keeps the pack under the 100 Wh TSA carry-on threshold. Pull-tabs make the printed status display readable from across the lounge.' },
    ],
    variantAxes: [{ name: 'Colour', values: ['Onyx', 'Pearl'] }],
    variants: [
      { sku: 'VOLT-20K-OX', barcode: '8908901200021', attributes: { 'Colour': 'Onyx' }, mrp: 5999, sellingPrice: 3999, purchasePrice: 2200, stockQuantity: 130, imageUrls: [ux('photo-1609592424823-e4b0a92ed1d3')] },
      { sku: 'VOLT-20K-PL', barcode: '8908901200022', attributes: { 'Colour': 'Pearl' }, mrp: 5999, sellingPrice: 3999, purchasePrice: 2200, stockQuantity: 110, imageUrls: [ux('photo-1609592424823-e4b0a92ed1d3')] },
    ],
  },

  {
    name: 'OmniLens Go 6',
    description: 'Pocket action camera with 5.3K60 video, dual screens, and a 1/1.7″ sensor.',
    sku: 'OMNI-GO6',
    barcode: '8909012300011',
    hsnCode: '85258090',
    brand: 'OmniLens',
    mrp: 39999,
    sellingPrice: 32499,
    purchasePrice: 23000,
    taxPercent: 18,
    stockQuantity: 35,
    lowStockThreshold: 6,
    unit: 'PCS',
    categorySlug: 'laptop-accessories',
    tags: ['action-cam', '5.3K', 'waterproof'],
    highlights: [
      '5.3K @ 60 fps, 4K @ 120 fps slow-mo',
      'HyperSmooth 7 stabilisation with horizon lock',
      'Dual rear + selfie touch displays',
      '1/1.7″ sensor — better low-light than the Go 5',
      'Waterproof to 10 metres without housing',
      'Mods ecosystem: Volta grip, Media Mod, Light Mod',
    ],
    specs: [
      { title: 'Imaging', rows: [
        { label: 'Sensor', value: '1/1.7″ CMOS' },
        { label: 'Video', value: '5.3K60, 4K120, 2.7K240' },
        { label: 'Photo', value: '27 MP from 5.3K frame' },
        { label: 'Stabilisation', value: 'HyperSmooth 7 + Horizon Lock 360°' },
      ]},
      { title: 'Build', rows: [
        { label: 'Waterproof', value: '10 m without housing, 60 m with Dive Housing' },
        { label: 'Weight', value: '154 g' },
        { label: 'Mounts', value: 'Folding fingers + 1/4″ thread' },
      ]},
      { title: 'Battery', rows: [
        { label: 'Enduro battery', value: '1900 mAh, cold-rated' },
        { label: 'Recording', value: 'Up to 90 min @ 5.3K60' },
      ]},
    ],
    offers: [
      { kind: 'COUPON', headline: 'Free 64GB microSD with code SHOOT64', code: 'SHOOT64' },
      { kind: 'BANK', headline: '₹2,500 off on Amex Cards' },
      { kind: 'EMI', headline: 'No-cost EMI from ₹3,611/mo for 9 months' },
    ],
    contentBlocks: [
      { kind: 'HERO', imageUrl: ux('photo-1502920917128-1aa500764cbd'), headline: 'Frame the impossible.', subtext: '5.3K. Stabilised. Waterproof. Pocketable.' },
    ],
    variantAxes: [{ name: 'Bundle', values: ['Camera Only', 'Creator Edition'] }],
    variants: [
      { sku: 'OMNI-GO6-CAM', barcode: '8909012300021', attributes: { 'Bundle': 'Camera Only' }, mrp: 39999, sellingPrice: 32499, purchasePrice: 23000, stockQuantity: 25, imageUrls: [ux('photo-1502920917128-1aa500764cbd')] },
      { sku: 'OMNI-GO6-CE', barcode: '8909012300022', attributes: { 'Bundle': 'Creator Edition' }, mrp: 47999, sellingPrice: 39999, purchasePrice: 28000, stockQuantity: 10, imageUrls: [ux('photo-1502920917128-1aa500764cbd')] },
    ],
  },

  {
    name: 'Crestwave 55" QLED Mini-LED 4K',
    description: '55-inch QLED TV with 1,200 mini-LED zones, 144 Hz gaming, and Dolby Vision IQ.',
    sku: 'CREST-55Q',
    barcode: '8900123400011',
    hsnCode: '85287200',
    brand: 'Crestwave',
    mrp: 119999,
    sellingPrice: 89999,
    purchasePrice: 68000,
    taxPercent: 18,
    stockQuantity: 18,
    lowStockThreshold: 4,
    unit: 'PCS',
    categorySlug: 'monitors',
    tags: ['QLED', 'mini-LED', 'Dolby-Vision'],
    highlights: [
      '55″ QLED with 1,200 mini-LED local dimming zones',
      '4K @ 144 Hz, VRR (FreeSync Premium Pro + G-Sync compatible)',
      'Dolby Vision IQ + HDR10+, IMAX Enhanced',
      'Filmmaker mode, automatic ambient calibration',
      '4×HDMI 2.1, eARC, 40W 2.1 speakers with Dolby Atmos',
      'Google TV with hands-free voice',
    ],
    specs: [
      { title: 'Display', tab: 'Display', rows: [
        { label: 'Size', value: '55 inches diagonal' },
        { label: 'Resolution', value: '3840 × 2160' },
        { label: 'Refresh rate', value: '144 Hz native' },
        { label: 'Backlight', value: 'Mini-LED, 1,200 dimming zones' },
        { label: 'Peak brightness', value: '2,000 nits' },
      ]},
      { title: 'Audio', tab: 'Audio', rows: [
        { label: 'Output', value: '40W (2.1)' },
        { label: 'Formats', value: 'Dolby Atmos, DTS:X' },
      ]},
      { title: 'Ports', tab: 'Ports', rows: [
        { label: 'HDMI', value: '4× HDMI 2.1 (one with eARC)' },
        { label: 'USB', value: '2× USB 2.0' },
        { label: 'Ethernet', value: 'Gigabit' },
        { label: 'Wi-Fi', value: 'Wi-Fi 6E' },
      ]},
    ],
    offers: [
      { kind: 'BANK', headline: '₹5,000 off on Standard Chartered Credit Cards' },
      { kind: 'EMI', headline: 'No-cost EMI up to 24 months' },
      { kind: 'EXCHANGE', headline: 'Up to ₹15,000 off on old TV exchange' },
      { kind: 'COUPON', headline: 'Free wall mount + installation', code: 'WALLFREE' },
    ],
    contentBlocks: [
      { kind: 'HERO', imageUrl: ux('photo-1593359677879-a4bb92f829d1'), headline: 'A cinema. On a wall.', subtext: 'Mini-LED. Dolby Vision IQ. 144Hz for the console nights.' },
      { kind: 'FEATURE', imageUrl: ux('photo-1593359677879-a4bb92f829d1'), side: 'RIGHT', title: 'Black that\'s actually black.', body: '1,200 mini-LED zones drive contrast that QLED used to envy. Filmmaker Mode disables every "enhancement" so a film looks like a film.' },
      { kind: 'COMPARISON', columns: [
        { label: '55Q', values: ['55″', 'Mini-LED', '1,200 zones', '144 Hz', '2,000 nits'] },
        { label: '55LED', values: ['55″', 'Edge-lit', '32 zones', '60 Hz', '450 nits'] },
        { label: '65Q', values: ['65″', 'Mini-LED', '1,800 zones', '144 Hz', '2,200 nits'] },
      ], rows: ['Size', 'Backlight', 'Local dimming', 'Refresh', 'Brightness'] },
    ],
    variantAxes: [],
    variants: [],
  },
];

async function seedProducts(shopId: number): Promise<void> {
  let createdCount = 0;
  let skippedCount = 0;

  for (const seed of PRODUCTS) {
    const exists = await prisma.product.findUnique({
      where: { shopId_sku: { shopId, sku: seed.sku } },
      select: { id: true, shopId: true },
    });
    if (exists) {
      skippedCount += 1;
      console.log(`  • skip ${seed.sku} — already exists (id=${exists.id})`);
      continue;
    }

    const { categorySlug, ...rest } = seed as SeedProduct & { categorySlug?: string };
    const categoryId = categorySlug ? await categoryIdBySlug(categorySlug) : undefined;
    if (categorySlug && !categoryId) {
      console.warn(
        `  ⚠  category "${categorySlug}" not found — did the API boot once to seed canonical categories? Continuing without a category FK.`,
      );
    }

    const product = await productsService.createProduct(
      { ...rest, categoryId },
      { shopId },
    );

    await productsService.setPublished(shopId, product.id, true);

    const fakeSold = 80 + Math.floor(Math.random() * 600);
    await prisma.product.update({
      where: { id: product.id },
      data: { soldLast30d: fakeSold, totalSold: fakeSold * 3 },
    });

    createdCount += 1;
    console.log(`  + created ${seed.sku} → ${seed.name} (id=${product.id}, soldLast30d=${fakeSold})`);
  }

  console.log(`\n✓ Products: ${createdCount} created, ${skippedCount} skipped.`);
}

async function seedTrendingEvents(): Promise<void> {
  const products = await prisma.product.findMany({
    where: { isActive: true, isPublished: true },
    select: { id: true },
  });
  if (products.length === 0) return;

  type EventInput = {
    clientUuid: string;
    eventType: 'IMPRESSION' | 'TAP' | 'ADD_TO_CART' | 'PURCHASE' | 'WISHLIST_ADD';
    productId: number;
    sessionId: string;
    occurredAt: Date;
  };
  const rows: EventInput[] = [];
  const now = Date.now();
  const WINDOW_MS = 12 * 60 * 60 * 1000;

  for (const p of products) {
    const lift = 1 + Math.random() * 2;
    const counts = {
      IMPRESSION: Math.round(120 * lift),
      TAP: Math.round(25 * lift),
      ADD_TO_CART: Math.round(6 * lift),
      PURCHASE: Math.round(2 * lift),
      WISHLIST_ADD: Math.round(4 * lift),
    } as const;

    for (const [eventType, count] of Object.entries(counts) as Array<
      [keyof typeof counts, number]
    >) {
      for (let i = 0; i < count; i++) {
        rows.push({
          clientUuid: crypto.randomUUID(),
          eventType,
          productId: p.id,
          sessionId: `seed-${crypto.randomUUID().slice(0, 8)}`,
          occurredAt: new Date(now - Math.random() * WINDOW_MS),
        });
      }
    }
  }

  await prisma.productEvent.createMany({ data: rows, skipDuplicates: true });
  console.log(`✓ Inserted ${rows.length} synthetic ProductEvents across ${products.length} products.`);
}

async function main(): Promise<void> {
  console.log(`\n▶ Seeding test merchant ${TARGET_EMAIL} …\n`);
  const { shopId } = await ensureMerchant();
  await seedProducts(shopId);

  console.log('\n▶ Synthesising trending events so the customer home feed surfaces the catalog …');
  await seedTrendingEvents();
  const trend = await trendingService.recomputeWindow();
  console.log(`✓ Trending recomputed — ${trend.products} products in the snapshot.`);

  console.log('\n✓ Done. Log in at the merchant app with:');
  console.log(`    email:    ${TARGET_EMAIL}`);
  console.log(`    password: ${TARGET_PASSWORD}\n`);
}

main()
  .catch((err) => {
    console.error('\n✗ Seed failed:', err);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

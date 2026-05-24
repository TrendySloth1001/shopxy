import 'dotenv/config';
import crypto from 'crypto';
import prisma from '../src/infra/db/prisma.js';
import { trendingService } from '../src/modules/trending/trending.service.js';

/// Seeds marketplace-side test data for nkumawat8956@gmail.com so the
/// new dashboards / rails surface non-empty state. Idempotent — re-run
/// safely; existing rows are detected and skipped or refreshed.

const uuid = () => crypto.randomBytes(8).toString('hex');

async function main() {
  const user = await prisma.user.findUniqueOrThrow({
    where: { email: 'nkumawat8956@gmail.com' },
    include: { shop: true },
  });
  if (!user.shop) throw new Error('User has no shop');
  const shopId = user.shop.id;

  // ── Publish the shop + a handful of products ────────────────────
  if (!user.shop.isPublished) {
    await prisma.shop.update({
      where: { id: shopId },
      data: { isPublished: true },
    });
    console.log('Published shop');
  }

  const products = await prisma.product.findMany({
    where: { shopId, isActive: true },
    orderBy: { id: 'asc' },
    take: 10,
  });
  for (const p of products) {
    if (!p.isPublished) {
      await prisma.product.update({
        where: { id: p.id },
        data: { isPublished: true },
      });
      console.log(`  published product #${p.id} ${p.name}`);
    }
  }
  console.log(`SEED: ${products.length} active products`);

  // ── Brand spotlight (APPROVED, live now) ────────────────────────
  const existingSpot = await prisma.brandSpotlight.findFirst({
    where: { shopId, status: 'APPROVED' },
  });
  if (!existingSpot) {
    await prisma.brandSpotlight.create({
      data: {
        shopId,
        dealLabel: 'Festive electronics — up to 40% off',
        subtitle: 'Curated cables, hubs, and gamepads',
        heroImageUrl:
          'https://images.unsplash.com/photo-1518770660439-4636190af475?w=800',
        bgColor: '#EFE4D6',
        accentColor: '#B23A2E',
        ctaTarget: 'collection:wedding-edit',
        startAt: new Date(Date.now() - 3_600_000),
        endAt: new Date(Date.now() + 30 * 86_400_000),
        status: 'APPROVED',
        reviewedAt: new Date(),
      },
    });
    console.log('SEED: brand spotlight (APPROVED)');
  }

  // ── Flash deal on first published product ───────────────────────
  const firstProduct = products[0];
  if (firstProduct) {
    const existingFlash = await prisma.flashSale.findFirst({
      where: { productId: firstProduct.id, isActive: true },
    });
    if (!existingFlash) {
      await prisma.flashSale.create({
        data: {
          productId: firstProduct.id,
          flashPrice: 999,
          stockLimit: 25,
          soldCount: 4,
          startAt: new Date(Date.now() - 3_600_000),
          endAt: new Date(Date.now() + 6 * 3_600_000),
          isActive: true,
        },
      });
      console.log(`SEED: flash sale on product #${firstProduct.id}`);
    }
  }

  // ── Promotion on second published product ───────────────────────
  if (products[1]) {
    const existingPromo = await prisma.promotion.findFirst({
      where: { productId: products[1].id, isActive: true },
    });
    if (!existingPromo) {
      await prisma.promotion.create({
        data: {
          shopId,
          productId: products[1].id,
          budgetPaise: 500_000, // ₹5,000
          dailyCapPaise: 100_000, // ₹1,000/day
          cpmPaise: 5_000, // ₹50/1k impressions
          startAt: new Date(Date.now() - 3_600_000),
          endAt: new Date(Date.now() + 14 * 86_400_000),
          isActive: true,
          deliveredImpressions: 320,
          spendPaise: 1_600, // 320 * 5000 / 1000
          spendTodayPaise: 1_600,
          spendTodayDate: new Date(),
        },
      });
      console.log(`SEED: promotion on product #${products[1].id}`);
    }
  }

  // ── Seed 240 ProductEvents across 4 published products ──────────
  const eventProducts = products.slice(0, 4);
  if (eventProducts.length >= 1) {
    const existing = await prisma.productEvent.count({
      where: { userId: user.id },
    });
    if (existing < 100) {
      const rows = [];
      const types: Array<'IMPRESSION' | 'TAP' | 'VIEW' | 'PURCHASE' | 'WISHLIST_ADD'> = [
        'IMPRESSION',
        'IMPRESSION',
        'IMPRESSION',
        'IMPRESSION',
        'IMPRESSION',
        'IMPRESSION',
        'IMPRESSION',
        'IMPRESSION',
        'TAP',
        'TAP',
        'TAP',
        'VIEW',
        'VIEW',
        'WISHLIST_ADD',
        'PURCHASE',
      ];
      const now = Date.now();
      for (let i = 0; i < 240; i++) {
        const p = eventProducts[i % eventProducts.length];
        const type = types[i % types.length];
        rows.push({
          clientUuid: uuid() + '-' + i,
          eventType: type,
          productId: p.id,
          userId: user.id,
          occurredAt: new Date(now - Math.floor(Math.random() * 23 * 3_600_000)),
        });
      }
      await prisma.productEvent.createMany({ data: rows, skipDuplicates: true });
      console.log(`SEED: 240 product events across ${eventProducts.length} products`);
    } else {
      console.log(`SEED: events already present (${existing}); skipping`);
    }
  }

  // ── Recently viewed for the user ────────────────────────────────
  for (const p of products.slice(0, 5)) {
    await prisma.recentlyViewed.upsert({
      where: { userId_productId: { userId: user.id, productId: p.id } },
      create: { userId: user.id, productId: p.id, lastViewedAt: new Date() },
      update: { lastViewedAt: new Date() },
    });
  }
  console.log('SEED: recently-viewed (top 5)');

  // ── Trigger trending recompute ──────────────────────────────────
  const trending = await trendingService.recomputeWindow();
  console.log(
    `TRENDING: recomputed snapshot for ${trending.products} products`,
  );

  // ── Build recommendation cache for the user ─────────────────────
  const recResult = await trendingService.recomputeForUser(user.id);
  console.log(`RECS: cached ${recResult.count} products for user`);

  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

import 'dotenv/config';
import crypto from 'crypto';
import prisma from '../src/infra/db/prisma.js';
import { trendingService } from '../src/modules/trending/trending.service.js';

const uuid = () => crypto.randomBytes(8).toString('hex');

async function main() {
  const user = await prisma.user.findUniqueOrThrow({
    where: { email: 'nkumawat8956@gmail.com' },
    include: { shop: true },
  });
  if (!user.shop) throw new Error('User has no shop');
  const shopId = user.shop.id;

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

  const existingBanner = await prisma.banner.findFirst({
    where: { shopId, placement: 'PROMO' },
  });
  if (!existingBanner) {
    await prisma.banner.create({
      data: {
        shopId,
        placement: 'PROMO',
        imageUrl:
          'https://images.unsplash.com/photo-1518770660439-4636190af475?w=800',
        linkUrl: `/shop/${user.shop.slug}`,
        sortOrder: 0,
        startAt: new Date(Date.now() - 3_600_000),
        endAt: new Date(Date.now() + 30 * 86_400_000),
        isActive: true,
      },
    });
    console.log('SEED: shop PROMO banner');
  }

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

  for (const p of products.slice(0, 5)) {
    await prisma.recentlyViewed.upsert({
      where: { userId_productId: { userId: user.id, productId: p.id } },
      create: { userId: user.id, productId: p.id, lastViewedAt: new Date() },
      update: { lastViewedAt: new Date() },
    });
  }
  console.log('SEED: recently-viewed (top 5)');

  const trending = await trendingService.recomputeWindow();
  console.log(
    `TRENDING: recomputed snapshot for ${trending.products} products`,
  );

  const recResult = await trendingService.recomputeForUser(user.id);
  console.log(`RECS: cached ${recResult.count} products for user`);

  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

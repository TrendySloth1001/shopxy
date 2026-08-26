import 'dotenv/config';
import prisma from '../src/infra/db/prisma.js';

async function main() {
  const email = 'nkumawat8956@gmail.com';
  const user = await prisma.user.findUnique({
    where: { email },
    select: {
      id: true,
      email: true,
      name: true,
      role: true,
      isPlatformAdmin: true,
      isActive: true,
      shop: { select: { id: true, name: true, slug: true, isPublished: true } },
    },
  });
  console.log('USER:', JSON.stringify(user, null, 2));

  if (!user) {
    console.log('NO USER FOUND — cannot audit further');
    return;
  }

  const shopId = user.shop?.id;
  console.log('SHOP_ID:', shopId);

  const productCountsByShop = await prisma.$queryRaw<
    Array<{ shop_id: number | null; count: bigint }>
  >`SELECT shop_id, COUNT(*)::bigint AS count FROM products GROUP BY shop_id ORDER BY shop_id`;
  console.log('PRODUCT_COUNT_BY_SHOP:', productCountsByShop);

  if (shopId) {
    const ourProducts = await prisma.product.findMany({
      where: { shopId },
      select: { id: true, name: true, sku: true, isActive: true, isPublished: true },
      take: 10,
    });
    console.log('THIS_SHOPS_PRODUCTS (first 10):', ourProducts);
  }

  const shops = await prisma.shop.findMany({
    select: { id: true, ownerUserId: true, name: true, slug: true, isPublished: true },
    take: 20,
  });
  console.log('ALL_SHOPS:', shops);

  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

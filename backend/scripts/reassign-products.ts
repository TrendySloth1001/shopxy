import 'dotenv/config';
import prisma from '../src/infra/db/prisma.js';

/// Reassigns products misallocated by the P0 backfill (which dumped
/// every pre-multi-tenant product into shop_id=1) over to the actual
/// account that's been managing them.
async function main() {
  const email = 'nkumawat8956@gmail.com';
  const user = await prisma.user.findUniqueOrThrow({
    where: { email },
    include: { shop: true },
  });
  if (!user.shop) throw new Error('User has no shop');

  const before = await prisma.product.findMany({
    select: { id: true, name: true, shopId: true },
  });
  console.log('BEFORE:', before);

  const result = await prisma.product.updateMany({
    where: { shopId: { not: user.shop.id } },
    data: { shopId: user.shop.id },
  });
  console.log(`Reassigned ${result.count} products → shop ${user.shop.id}`);

  const after = await prisma.product.findMany({
    where: { shopId: user.shop.id },
    select: { id: true, name: true, isActive: true, isPublished: true },
  });
  console.log('AFTER (this shops products):', after);

  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

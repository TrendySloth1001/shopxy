import 'dotenv/config';
import { seedHsnMaster } from '../modules/hsn/hsn.seed.js';
import prisma from '../infra/db/prisma.js';

seedHsnMaster()
  .then((r) => {
    console.log('hsn seed:', JSON.stringify(r, null, 2));
    return prisma.$disconnect();
  })
  .then(() => process.exit(0))
  .catch(async (e) => {
    console.error(e);
    await prisma.$disconnect().catch(() => undefined);
    process.exit(1);
  });

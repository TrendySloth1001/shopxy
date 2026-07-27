import 'dotenv/config';
import { seedHsnMaster } from '../modules/hsn/hsn.seed.js';
import prisma from '../infra/db/prisma.js';

/// Run the HSN master sync on demand.
///
/// The seed also runs at boot, but that couples a data refresh to a restart.
/// After an import you want to see the diff — created / updated / superseded —
/// before deciding whether it's right, and a superseded row is a rate that
/// changed under existing products.
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

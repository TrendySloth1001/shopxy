import bcrypt from 'bcrypt';
import prisma from '../infra/db/prisma.js';

const EMAIL = 'staff1@test.com';
const NAME = 'Test Staff';
const PASSWORD = 'Test1234';

async function main() {
  const email = EMAIL.toLowerCase();
  const existing = await prisma.user.findUnique({
    where: { email },
    select: { id: true, role: true, shopMembership: { select: { id: true } } },
  });

  if (existing) {
    if (existing.shopMembership) {
      console.log(
        `ℹ ${email} already exists (id=${existing.id}) and is ON a team. ` +
          `Remove them from the team first to re-test the join flow.`,
      );
    } else {
      await prisma.user.update({
        where: { id: existing.id },
        data: { role: 'OWNER', isActive: true },
      });
      console.log(
        `✓ ${email} already exists (id=${existing.id}); reset to a clean ` +
          `shopless OWNER. Password: ${PASSWORD}`,
      );
    }
    await prisma.$disconnect();
    return;
  }

  const passwordHash = await bcrypt.hash(PASSWORD, 12);
  const user = await prisma.user.create({
    data: {
      email,
      name: NAME,
      passwordHash,
      role: 'OWNER',
      acceptedAt: new Date(),
    },
    select: { id: true },
  });
  console.log(
    `✓ Created shopless OWNER ${email} (id=${user.id}). Password: ${PASSWORD}\n` +
      `  Invite this email from an owner's Team & roles screen, then log in ` +
      `as it to see the join-request screen.`,
  );
  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

/**
 * READ-ONLY diagnostic: for the most recent online-paid customer orders, print
 * the gateway intent, the child invoices, and the receipts posted against them.
 * Pinpoints WHY a paid order shows unpaid on the merchant invoice.
 *
 * Run: npx tsx scripts/diag-order-receipts.ts
 */
import prisma from '../src/infra/db/prisma.js';

async function main() {
  // Most recent orders that have a gateway intent against them.
  const gws = await prisma.gatewayPayment.findMany({
    where: { targetType: 'ORDER' },
    orderBy: { id: 'desc' },
    take: 8,
    select: {
      id: true,
      status: true,
      amount: true,
      provider: true,
      targetId: true,
      providerOrderRef: true,
      providerPaymentRef: true,
      idempotencyKey: true,
      customerUserId: true,
    },
  });

  if (gws.length === 0) {
    console.log('No ORDER-target gateway intents found at all.');
    return;
  }

  for (const gw of gws) {
    const orderId = gw.targetId;
    const order = await prisma.customerOrder.findUnique({
      where: { id: orderId },
      select: {
        id: true,
        paymentStatus: true,
        estimatedTotal: true,
        walletPaid: true,
        couponDiscount: true,
        customerUserId: true,
        shopOrders: {
          select: {
            id: true,
            shopId: true,
            status: true,
            invoiceId: true,
            estimatedTotal: true,
            invoice: { select: { id: true, total: true, status: true, invoiceNo: true } },
          },
        },
      },
    });

    console.log('\n══════════════════════════════════════════════════════');
    console.log(
      `GatewayPayment#${gw.id}  status=${gw.status}  amount=${gw.amount}  ` +
        `targetOrder=${orderId}  payRef=${gw.providerPaymentRef ?? '—'}  key=${gw.idempotencyKey ?? '—'}`,
    );
    if (!order) {
      console.log(`  !! CustomerOrder#${orderId} NOT FOUND`);
      continue;
    }
    console.log(
      `CustomerOrder#${order.id}  paymentStatus=${order.paymentStatus}  ` +
        `est=${order.estimatedTotal}  wallet=${order.walletPaid}  coupon=${order.couponDiscount}`,
    );

    for (const child of order.shopOrders) {
      const inv = child.invoice;
      console.log(
        `  child PR#${child.id} shop=${child.shopId} status=${child.status} ` +
          `invoiceId=${child.invoiceId ?? '—'} ` +
          (inv ? `invoice#${inv.id}(${inv.invoiceNo}) invStatus=${inv.status} total=${inv.total}` : 'NO INVOICE'),
      );
      if (inv) {
        const pays = await prisma.payment.findMany({
          where: { invoiceId: inv.id },
          select: {
            id: true,
            type: true,
            amount: true,
            mode: true,
            note: true,
            voidedAt: true,
            idempotencyKey: true,
            shopId: true,
          },
        });
        if (pays.length === 0) {
          console.log('      receipts: (none)  <-- merchant sees UNPAID');
        }
        for (const p of pays) {
          console.log(
            `      payment#${p.id} type=${p.type} amount=${p.amount} mode=${p.mode} ` +
              `shop=${p.shopId} void=${p.voidedAt ? 'Y' : 'n'} key=${p.idempotencyKey ?? '—'} note=${p.note ?? ''}`,
          );
        }
      }
    }

    // What the reconciler WOULD see for the gateway slice.
    const capturedForOrder = await prisma.gatewayPayment.findFirst({
      where: { targetType: 'ORDER', targetId: orderId, status: 'CAPTURED' },
      select: { id: true, amount: true },
    });
    console.log(
      `  reconciler gw lookup (status=CAPTURED): ${
        capturedForOrder ? `FOUND #${capturedForOrder.id} amount=${capturedForOrder.amount}` : 'NONE — gateway slice will post nothing'
      }`,
    );
    const confirmedWithInvoice = order.shopOrders.filter(
      (c) => c.status === 'CONFIRMED' && c.invoiceId != null,
    );
    console.log(
      `  reconciler child filter (CONFIRMED + invoiceId): ${confirmedWithInvoice.length} of ${order.shopOrders.length}`,
    );
  }
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });

// Smoke tests for the rebuilt merchant dashboard components (the 1:1 port of
// merchant-web). Each component is rendered with realistic sample data at
// phone (360), tablet (768) and desktop (1440) widths, and we assert no
// layout/paint exception was thrown — the responsive grids, custom-painted
// trend chart and infographic pies are the risk surface.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopxy/features/dashboard/domain/entities/dashboard_stats.dart';
import 'package:shopxy/features/dashboard/presentation/widgets/action_center.dart';
import 'package:shopxy/features/dashboard/presentation/widgets/alerts.dart';
import 'package:shopxy/features/dashboard/presentation/widgets/analytics.dart';
import 'package:shopxy/features/dashboard/presentation/widgets/kpi_row.dart';
import 'package:shopxy/features/dashboard/presentation/widgets/onboarding_checklist.dart';
import 'package:shopxy/features/dashboard/presentation/widgets/operations.dart';
import 'package:shopxy/features/dashboard/presentation/widgets/period_switcher.dart';
import 'package:shopxy/features/dashboard/presentation/widgets/recent_activity.dart';
import 'package:shopxy/features/dashboard/presentation/widgets/trend_card.dart';

const _widths = <double>[360, 768, 1440];

DashboardKpis _kpis() => const DashboardKpis(
      sales: KpiMoney(value: 45670, prev: 40000, deltaPct: 12),
      profit: KpiProfit(value: 12340, prev: 13000, deltaPct: -3, margin: 27),
      receivables: KpiBalance(outstanding: 8900, count: 3),
      payables: KpiBalance(outstanding: 15500, count: 5),
    );

DashboardTrend _trend() {
  final labels = [for (var i = 0; i < 14; i++) '2026-06-${(12 + i).toString().padLeft(2, '0')}'];
  List<double> wave(double base) =>
      [for (var i = 0; i < 14; i++) base + (i % 5) * 800 + (i % 3) * 300];
  return DashboardTrend(
    labels: labels,
    sales: wave(2000),
    previous: wave(1500),
    purchases: wave(900),
    returns: [for (var i = 0; i < 14; i++) (i % 4) * 120],
    paymentSeries: [
      PaymentSeries(mode: 'UPI', values: wave(800)),
      PaymentSeries(mode: 'CASH', values: wave(500)),
      PaymentSeries(mode: 'CARD', values: wave(300)),
    ],
  );
}

DashboardInsights _insights() => const DashboardInsights(
      topProducts: [
        InsightProduct(name: 'Basmati Rice 5kg', revenue: 24000, quantity: 40),
        InsightProduct(name: 'Sunflower Oil 1L', revenue: 18000, quantity: 60),
        InsightProduct(name: 'Toor Dal 1kg', revenue: 12000, quantity: 80),
        InsightProduct(name: 'Sugar 1kg', revenue: 9000, quantity: 90),
        InsightProduct(name: 'Atta 10kg', revenue: 7000, quantity: 20),
        InsightProduct(name: 'Tea 500g', revenue: 5000, quantity: 25),
        InsightProduct(name: 'Salt 1kg', revenue: 3000, quantity: 100),
      ],
      topCategories: [
        InsightCategory(name: 'Groceries', revenue: 40000),
        InsightCategory(name: 'Beverages', revenue: 22000),
        InsightCategory(name: 'Snacks', revenue: 15000),
        InsightCategory(name: 'Household', revenue: 8000),
      ],
      slowMovers: [
        InsightSlowMover(name: 'Imported Olives', stock: 120, sold: 1),
        InsightSlowMover(name: 'Truffle Sauce', stock: 80, sold: 0),
        InsightSlowMover(name: 'Quinoa 1kg', stock: 45, sold: 2),
      ],
    );

DashboardActionQueue _queue() => const DashboardActionQueue(
      orders: 3,
      quotations: 2,
      returns: 1,
      drafts: 5,
      lowStock: 4,
      outOfStock: 2,
    );

Future<void> _pump(WidgetTester tester, double width, Widget child) async {
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    ),
  );
  await tester.pump();
  expect(tester.takeException(), isNull);
}

void main() {
  final ops = DashboardOperations(
    inventoryValue: 245000,
    till: DashboardTill(
      shiftId: 1,
      openedAt: DateTime(2026, 6, 26, 14, 30),
      salesCount: 5,
      salesGross: 3200,
      expectedCash: 3200,
      tenders: const [
        DashboardTender(mode: 'UPI', amount: 1500, count: 3),
        DashboardTender(mode: 'CASH', amount: 1700, count: 2),
      ],
    ),
    gstMtd: DashboardGstMtd(
      monthStart: DateTime(2026, 6, 1),
      outputTax: 45000,
      inputTax: 32550,
      netPayable: 12450,
    ),
  );

  for (final w in _widths) {
    testWidgets('KpiRow renders @${w.toInt()}', (t) async {
      await _pump(t, w, KpiRow(kpis: _kpis()));
    });
    testWidgets('TrendCard renders @${w.toInt()}', (t) async {
      await _pump(t, w, TrendCard(trend: _trend()));
    });
    testWidgets('Analytics renders @${w.toInt()}', (t) async {
      await _pump(t, w, Analytics(insights: _insights()));
    });
    testWidgets('ActionCenter renders @${w.toInt()}', (t) async {
      await _pump(t, w, ActionCenter(queue: _queue()));
    });
    testWidgets('Operations renders @${w.toInt()}', (t) async {
      await _pump(t, w, Operations(operations: ops));
    });
    testWidgets('RecentActivity renders @${w.toInt()}', (t) async {
      await _pump(
          t,
          w,
          RecentActivity(transactions: [
            DashboardTransaction(
              id: 1,
              productId: 10,
              direction: 'IN',
              quantity: 50,
              sourceType: 'INVOICE',
              sourceId: 7,
              createdAt: DateTime(2026, 6, 26, 14, 30),
              productName: 'Basmati Rice 5kg',
            ),
            DashboardTransaction(
              id: 2,
              productId: 11,
              direction: 'OUT',
              quantity: 10,
              createdAt: DateTime(2026, 6, 26, 13, 15),
              productName: 'Sunflower Oil 1L',
            ),
          ]));
    });
    testWidgets('Alerts renders @${w.toInt()}', (t) async {
      await _pump(
          t,
          w,
          const Alerts(alerts: [
            DashboardAlert(
              id: 'low-stock',
              severity: AlertSeverity.warning,
              message: '6 products are low or out of stock — reorder soon.',
              href: '/dashboard/products',
            ),
          ]));
    });
    testWidgets('OnboardingChecklist renders @${w.toInt()}', (t) async {
      await _pump(
          t,
          w,
          const OnboardingChecklist(
            onboarding: DashboardOnboarding(
              totalProducts: 1,
              activeProducts: 1,
              hasInvoices: false,
              hasParties: false,
            ),
            payoutsEnabled: false,
          ));
    });
    testWidgets('PeriodSwitcher renders @${w.toInt()}', (t) async {
      await _pump(
          t,
          w,
          PeriodSwitcher(value: DashboardPeriod.week, onChanged: (_) {}));
    });
  }
}

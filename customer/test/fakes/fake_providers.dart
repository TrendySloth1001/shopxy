import 'package:shopxy_customer/core/auth/token_manager.dart';
import 'package:shopxy_customer/core/network/api_client.dart';
import 'package:shopxy_customer/features/notifications/data/datasources/notifications_remote_data_source.dart';
import 'package:shopxy_customer/features/notifications/domain/entities/invitation.dart';
import 'package:shopxy_customer/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:shopxy_customer/features/shops/data/datasources/me_remote_data_source.dart';
import 'package:shopxy_customer/features/shops/domain/entities/linked_shop.dart';
import 'package:shopxy_customer/features/shops/presentation/providers/shops_provider.dart';

final _inertApi = ApiClient(TokenManager());
final _inertNotifsDs = NotificationsRemoteDataSource(_inertApi);
final _inertInvitesDs = InvitationsRemoteDataSource(_inertApi);
final _inertMeDs = MeRemoteDataSource(_inertApi);

class FakeShopsProvider extends ShopsProvider {
  FakeShopsProvider({
    this.seedShops = const [],
    this.seedInvoices = const {},
    this.seedIsLoading = false,
    this.seedError,
  }) : super(_inertMeDs);

  final List<LinkedShop> seedShops;
  final Map<String, List<ShopInvoice>> seedInvoices;
  final bool seedIsLoading;
  final String? seedError;

  @override
  List<LinkedShop> get shops => seedShops;
  @override
  bool get isLoading => seedIsLoading;
  @override
  String? get error => seedError;
  @override
  Future<void> loadShops() async {}
  @override
  Future<void> loadInvoices(LinkedShop s) async {}
  @override
  List<ShopInvoice>? invoicesFor(LinkedShop s) => seedInvoices[s.id];
  @override
  bool isLoadingInvoices(LinkedShop s) => false;
  @override
  String? invoiceErrorFor(LinkedShop s) => null;
}

class FakeNotificationsProvider extends NotificationsProvider {
  FakeNotificationsProvider({this.seedPending = const []})
      : super(_inertNotifsDs, _inertInvitesDs);

  final List<Invitation> seedPending;

  @override
  List<Invitation> get incoming => seedPending;
  @override
  List<Invitation> get pendingIncoming =>
      seedPending.where((i) => i.isPending).toList(growable: false);
  @override
  Future<void> loadIncoming({String status = 'ALL'}) async {}
  @override
  Future<void> loadInbox({bool unreadOnly = false}) async {}
  @override
  Future<void> refreshUnreadCount() async {}
}

LinkedShop fakeShop({
  String id = '1',
  String name = 'Acme Stores',
  ShopRole role = ShopRole.party,
  int invoiceCount = 0,
}) =>
    LinkedShop(
      id: id,
      role: role,
      name: name,
      email: 'acme@example.com',
      phone: '555-0100',
      address: null,
      invoiceCount: invoiceCount,
    );

ShopInvoice fakeInvoice({
  String id = '100',
  String invoiceNo = 'INV-001',
  double total = 1500,
  String type = 'SALE',
  int itemCount = 3,
}) =>
    ShopInvoice(
      id: id,
      invoiceNo: invoiceNo,
      type: type,
      status: 'CONFIRMED',
      invoiceDate: DateTime(2026, 5, 1),
      subtotal: total - 100,
      taxAmount: 100,
      discount: 0,
      total: total,
      itemCount: itemCount,
    );

Invitation fakePendingInvitation({
  String id = '1',
  String fromShopName = 'Acme Stores',
  bool isParty = true,
}) =>
    Invitation(
      id: id,
      fromUserId: '1',
      toEmail: 'me@example.com',
      toUserId: '2',
      linkType: isParty ? InviteLinkType.party : InviteLinkType.vendor,
      partyId: isParty ? '99' : null,
      vendorId: isParty ? null : '99',
      status: InviteStatus.pending,
      message: null,
      fromShopName: fromShopName,
      displayName: 'You',
      expiresAt: DateTime.now().add(const Duration(days: 7)),
      respondedAt: null,
      createdAt: DateTime.now(),
    );

ShopInvoiceDetail fakeInvoiceDetail({
  String id = '100',
  String invoiceNo = 'INV-001',
  double subtotal = 1000,
  double tax = 100,
  double discount = 50,
}) =>
    ShopInvoiceDetail(
      id: id,
      invoiceNo: invoiceNo,
      type: 'SALE',
      status: 'CONFIRMED',
      invoiceDate: DateTime(2026, 5, 1),
      subtotal: subtotal,
      taxAmount: tax,
      discount: discount,
      total: subtotal + tax - discount,
      itemCount: 1,
      note: null,
      shopName: 'Acme Stores',
      shopPhone: '555-0100',
      shopGstin: null,
      items: [
        ShopInvoiceItem(
          id: '1',
          productName: 'Widget',
          productSku: 'W-1',
          hsn: null,
          unit: 'PCS',
          quantity: 2,
          unitPrice: 500,
          taxPercent: 10,
          discount: 0,
          total: 1000,
        ),
      ],
    );
